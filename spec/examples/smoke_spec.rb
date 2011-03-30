require File.dirname(__FILE__) + '/../spec_helper'

describe FlexibleApiServer do

  include Rack::Test::Methods

  def app
    FlexibleApiServer::App
  end

  it 'should be able to see its own version' do
    FlexibleApiServer::VERSION.should_not be_empty
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
