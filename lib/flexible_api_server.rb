require 'bundler/setup'
require 'active_record'
require 'sinatra/base'
require 'sinatra/respond_to'
require 'json'

require 'flexible_api'

class ActiveRecord::Base
  if ActiveRecord::VERSION::MAJOR < 3
    named_scope :limit, lambda { |l| { :limit => l } }
    named_scope :offset, lambda { |o| { :offset => o } }
  end
end



module FlexibleApiServer

  class App < Sinatra::Base
    # to allow periods in parameters without it being a MIME type, respondto tries to replace all periods, so we intercept before
    before do 
      request.path_info = request.path_info.sub(/\.(?=([.*\)]))/, '\period')
    end
    
    register Sinatra::RespondTo
  
    mime_type :jsonp, 'application/javascript'
    mime_type :js, 'application/json'
    mime_type :xml, 'application/xml'

    set :assume_xhr_is_js, true
    set :default_content, :js
    set :raise_errors, false
    set :show_exceptions, false
    set :views, File.dirname(__FILE__) + '/../views'

    FILTERED_COLUMNS = [:password, :password_confirmation]
    ALLOWED_FORMATS = [:js, :xml, :jsonp]

    def assign(k, v)
      @assign ||= {}
      @assign[k] = v
      nil
    end

    def free_render(code, hash = '') # blank by default, not nil
      status code
      # Filter some things out
      FILTERED_COLUMNS.each do |column|
        hash[column] = '[filtered]' if hash.has_key?(column)
      end if hash.is_a?(Hash)
      # and respond
      charset 'utf-8'
      format :js unless ALLOWED_FORMATS.include? format
      respond_to do |wants|
        wants.jsonp do
          (params[:callback] || 'callback') + "(#{hash.to_json});"
        end
        wants.js do
          hash.to_json
        end
        wants.xml do
          hash.to_xml
        end
      end
    end

    # TODO too generic
    error NameError do
      free_render 404, :message => "No such type: #{params[:model]}"
    end

    error FlexibleApi::NoSuchRequestLevelError do
      free_render 400, :message => request.env['sinatra.error'].message
    end

    # TODO too generic
    error ActiveRecord::RecordNotFound do
      free_render 404, :message => request.env['sinatra.error'].message
    end

    # TODO too generic
    error NoMethodError do
      free_render 404, :message => "Unknown method '#{request.env['sinatra.error'].name}' on #{params[:model]}"
    end

    get '/favicon' do
      headers['Cache-Control'] = 'public, max-age=7776000'
      free_render 404
    end

    post '/:model' do
      model_klass = params[:model].singularize.camelize.constantize

      record = model_klass.new(request.POST)
      @assign.each { |k, v| record.send(:"#{k}=", v) } unless @assign.nil?
      if record.save
        free_render 200, record.to_hash(requested_level)
      else
        free_render 422, :message => 'Validation error', :errors => record.errors
      end
    end

    get '/:model' do
      model_param, scope_param = params[:model].split ':', 2
      query = model_param.singularize.camelize.constantize

      query = add_scopes(query, scope_param)

      if params[:count_only] == 'true'
        free_render 200, :count => query.count
      else
        query = add_limit_and_offset query
        records = query.find_all_hash(:request_level => requested_level)
        free_render 200, records
      end
    end

    delete '/:model' do
      free_render 404, :message => 'not implemented'
    end

    get '/:model/:id' do
      model_klass = params[:model].singularize.camelize.constantize
      record = model_klass.find_hash(params[:id], :request_level => requested_level)
      free_render 200, record
    end

    put '/:model/:id' do
      model_klass = params[:model].singularize.camelize.constantize
      record = model_klass.find(params[:id])

      record.attributes = request.POST
      @assign.each { |k, v| record.send(:"#{k}=", v) } unless @assign.nil?
      if record.save
        free_render 200, record.to_hash(requested_level)
      else
        free_render 422, :message => 'Validation error', :errors => record.errors
      end
    end

    delete '/:model/:id' do
      free_render 404, :message => 'not implemented'
    end

    post '/:model/:id/:relation' do

      model_klass = params[:model].singularize.camelize.constantize

      model_instance = model_klass.find(params[:id])
      relation = model_instance.send(params[:relation].to_sym)

      record = relation.new(request.POST)
      @assign.each { |k, v| record.send(:"#{k}=", v) } unless @assign.nil?

      if record.save
        free_render 200, record.to_hash(requested_level)
      else
        free_render 422, :message => 'Validation error', :errors => record.errors
      end
    end

    get '/:model/:id/:relation' do

      model_klass = params[:model].singularize.camelize.constantize
      relation_param, scope_param = params[:relation].split ':', 2

      record = model_klass.find(params[:id]) # TODO only select the thing needed for the join
      query = record.send(relation_param)

      return free_render 200, nil if query.nil?

      if query.is_a?(ActiveRecord::Base)
        free_render 200, query.to_hash(requested_level)
      else
        # Scope it
        query = add_scopes(query, scope_param)
        # Render the result
        if params[:count_only] == 'true'
          free_render 200, :count => query.count
        else
          query = add_limit_and_offset(query)
          free_render 200, query.find_all_hash(:request_level => requested_level)
        end
      end
    end

    put '/:model/:id/:relation' do
      free_render 404, :message => 'not implemented'
    end

    delete '/:model/:id/:relation' do
      free_render 404, :message => 'not implemented'
    end

    get '/' do
      format 'html'
      respond_to do |wants|
        wants.html do
          @model_details = FlexibleApi.flexible_models.sort_by { |m| m.name }
          path = "./config/locales/#{I18n.locale}/descriptions.yml"
          @copy = File.exists?(path) ? YAML::load(File.open(path, 'r')) : {}
          erb :doc_index
        end
      end
    end

    private

    DEFAULT_LIMIT = 50

    # override this method to allow backspace (%5C) escaping commas, parentheses, and backspaces in params
    def add_scopes(query, scope_param)
      scopes = []
      scopes.concat scope_param.split ':' unless scope_param.nil?
      scopes.concat params[:scopes] if params[:scopes].is_a?(Array)
      scopes.each do |scope|
        method, arg_string = scope.split(/(?<=[^\\])\(/)
        if !arg_string.nil?
          arg_string = arg_string.chop.gsub(/\\\\/, "\\backspace").gsub(/\\period/, '.')
          # split on non-escaped commas
          args = arg_string.split(/(?<=[^\\]),/).map(&:strip)
          # map escaped characters to normal values
          args = args.map {|arg| arg.gsub(/\\,/, ',')}.map {|arg| arg.gsub(/\\\(/, '(')}.map {|arg| arg.gsub(/\\backspace/, '\\')}
          query = query.send method.to_sym, *args
        else
          query = query.send method.to_sym
        end
      end
      query
    end

    def add_limit_and_offset(query)
      limit = params[:limit].to_i
      limit = DEFAULT_LIMIT if limit <= 0

      offset = params[:offset].to_i
      offset = 0 if offset < 0

      query.limit(limit).offset(offset)
    end

    def requested_level
      params[:request_level] || params[:level]
    end

  end

end
