require File.dirname(__FILE__) + '/../spec_helper'

describe FlexibleApiServer do

  include Rack::Test::Methods

  def app
    FlexibleApiServer::App
  end

  it 'should be able to get the doc index' do
    get '/'
    last_response.should be_ok
  end

end
