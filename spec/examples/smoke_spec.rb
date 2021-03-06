require File.dirname(__FILE__) + '/../spec_helper'

describe FlexibleApiServer do

  include Rack::Test::Methods

  def app
    FlexibleApiServer::App
  end

  before :all do
    Thing.destroy_all
  end

  it 'should be able to see its own version' do
    FlexibleApiServer::VERSION.should_not be_empty
  end

  it 'should return application/json as the content type for json requests' do
    get '/things', :format => 'js'
    last_response.headers['Content-type'].should == 'application/json;charset=utf-8'
  end

  it 'should be able to return data as jsonp with a default callback' do
    get '/things', :format => 'jsonp'
    last_response.headers['Content-type'].should == 'application/javascript;charset=utf-8'
    last_response.body.should == 'callback([]);'
  end

  it 'should be able to return data as jsonp with a non-default callback' do
    get '/things', :format => 'jsonp', :callback => 'john'
    last_response.headers['Content-type'].should == 'application/javascript;charset=utf-8'
    last_response.body.should == 'john([]);'
  end

  it 'should return application/xml as the content type for json requests' do
    get '/things', :format => 'xml'
    last_response.headers['Content-type'].should == 'application/xml;charset=utf-8'
  end

  it 'should give a 404 to favicon.ico' do
    get '/favicon.ico'
    last_response.should be_not_found
    last_response.headers['Cache-Control'].should =~ /max-age=7776000$/
  end

  it 'should be able to get the doc index' do
    get '/'
    last_response.should be_ok
  end

end
