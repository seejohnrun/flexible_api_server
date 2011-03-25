require File.dirname(__FILE__ ) + '/../spec_helper'

describe FlexibleApiServer do

  include Rack::Test::Methods

  def app
    FlexibleApiServer::App
  end

  ActiveRecord::Base.connection.execute 'drop table if exists things'
  ActiveRecord::Base.connection.execute 'drop table if exists buckets'
  ActiveRecord::Base.connection.execute 'create table things (id integer primary key autoincrement, name varchar(255), bucket_id integer)'
  ActiveRecord::Base.connection.execute 'create table buckets (id integer primary key autoincrement)'

  class Thing < ActiveRecord::Base
    include FlexibleApi
    belongs_to :bucket
    validates_presence_of :name
    scope :apples_only, where('name = ?', 'apple')
    scope :starts_with, lambda { |s| where('name LIKE ?', "#{s}%") }
    define_request_level :name_only do |level|
      level.fields :name
    end
  end
  class Bucket < ActiveRecord::Base
    include FlexibleApi
    has_many :things
    define_request_level :simple do |level|
      level.fields :id
      level.includes :things, :request_level => :name_only
    end
  end

  it 'should be able to get a list of all things' do
    Thing.create(:name => 'banana')
    get '/things?request_level=name_only'
    last_response.should be_ok
    JSON::parse(last_response.body).should == [{ 'name' => 'banana' }]
  end

  it 'should be able to get an individual thing by id' do
    thing = Thing.create(:name => 'apple')
    get "/things/#{thing.id}?request_level=name_only"
    last_response.should be_ok
    JSON::parse(last_response.body).should == { 'name' => 'apple' }
  end

  it 'should be able to get a bucket for a thing' do
    thing = Thing.create(:name => 'apple')
    get "/things/#{thing.id}/bucket?request_level=simple"
    last_response.should be_ok
    last_response.body.should == 'null' # many to one
  end

  it 'should be able to get a list of things for a bucket that is empty' do
    bucket = Bucket.create
    get "/buckets/#{bucket.id}/things?request_level=name_only"
    last_response.should be_ok
    JSON::parse(last_response.body).should == [] # one to many
  end

  it 'should be able to get a list of things for a bucket that is not empty' do
    bucket = Bucket.create
    bucket.things.create(:name => 'apple')
    get "/buckets/#{bucket.id}/things?request_level=name_only"
    last_response.should be_ok
    JSON::parse(last_response.body).should == [{'name' => 'apple'}] # one to many
  end

  it 'should not be able to call wrong request levels' do
    get '/buckets?request_level=name_only'
    last_response.status.should == 400
    JSON::parse(last_response.body).should == { 'message' => 'There is no request level \'name_only\' for Bucket' }
  end

  it 'should fail gracefully when trying to access a non-existent base type' do
    get '/muppets?request_level=name_only'
    last_response.status.should == 404
    JSON::parse(last_response.body).should == { 'message' => 'No such type: muppets' }
  end

  it 'should be able to perform a get and use the default request level (all by default)' do
    thing = Thing.create(:name => 'banana')
    get "/things/#{thing.id}"
    last_response.should be_ok
  end

  it 'should be able to create a record via the api' do
    post '/things', :name => 'john'
    last_response.should be_ok
    data = JSON::parse(last_response.body)
    data['id'].should be > 0
    data['name'].should == 'john'
    data['bucket_it'].should be_nil
  end

  it 'should get a 404 when trying to create a record of a non-existant class' do
    post '/muppets', :name => 'john'
    last_response.status.should == 404
  end

  it 'should get validation errors back when trying to save and failing' do
    post '/things'
    last_response.status.should == 422
    data = JSON::parse(last_response.body)
    data['message'].should == 'Validation error'
    data['errors'].should_not be_empty
  end

  it 'should get a 404 when trying to get a record that does not exist' do
    get '/things/this'
    last_response.status.should == 404
  end

  it 'should be able to update a record' do
    thing = Thing.create(:name => 'john')
    put "/things/#{thing.id}", :name => 'john2'
    last_response.should be_ok
    thing.reload
    thing.name.should == 'john2'
  end

  it 'should return updated versions when updating a record' do
    thing = Thing.create(:name => 'john')
    put "/things/#{thing.id}", :name => 'john2'
    last_response.should be_ok
  end

  it 'should return errors when updating and invalidating a record' do
    thing = Thing.create(:name => 'john')
    put "/things/#{thing.id}", :name => nil
    last_response.status.should == 422
    data = JSON::parse(last_response.body)
    data['message'].should == 'Validation error'
  end
  
  it 'should be able to work with scopes' do
    Thing.destroy_all
    Thing.create(:name => 'banana')
    Thing.create(:name => 'apple')
    get '/things:apples_only'
    last_response.should be_ok
    JSON::parse(last_response.body).length.should == 1
  end

  it 'should get a 404 when trying to use a scope that does not exist' do
    get '/things:recent'
    last_response.should be_not_found
  end

  it 'should be able to apply limits to queries' do
    5.times { Thing.create(:name => 'john') }
    get '/things?limit=3'
    JSON::parse(last_response.body).length.should == 3
  end

  it 'should be able to use offsets to walk through results' do
    Thing.destroy_all
    3.times { Thing.create(:name => 'john') }

    get '/things?limit=2&offset=2'
    JSON::parse(last_response.body).length.should == 1 # odd number 
  end

  it 'should be able to pass count_only and get a count back' do
    get '/things?count_only=true'
    JSON::parse(last_response.body)['count'].should be > 0
  end

  it 'should be able to do count_only through a relation' do
    bucket = Bucket.create
    5.times { bucket.things.create(:name => 'john') }

    get "/buckets/#{bucket.id}/things?count_only=true"
    last_response.should be_ok
    JSON::parse(last_response.body)['count'].should == 5
  end

  it 'should be able to use limit and offset through a relation' do
    bucket = Bucket.create
    3.times { bucket.things.create(:name => 'john') }

    get "/buckets/#{bucket.id}/things?limit=2&offset=2"
    last_response.should be_ok
    JSON::parse(last_response.body).length.should == 1
  end

  it 'should be able to use scopes on a relation' do
    bucket = Bucket.create
    2.times { bucket.things.create(:name => 'apple') }
    2.times { bucket.things.create(:name => 'banana') }

    get "/buckets/#{bucket.id}/things:apples_only"
    last_response.should be_ok
    JSON::parse(last_response.body).each do |thing|
      thing['name'].should == 'apple'
    end
  end

  it 'should be able to use scopes on a relation using count' do
    bucket = Bucket.create
    2.times { bucket.things.create(:name => 'apple') }
    2.times { bucket.things.create(:name => 'banana') }

    get "/buckets/#{bucket.id}/things:apples_only?count_only=true"
    last_response.should be_ok
    JSON::parse(last_response.body)['count'].should == 2
  end

  it 'should be able to use level in place of request_level param' do
    thing = Thing.create(:name => 'john')
    get "/things/#{thing.id}?level=name_only"
    last_response.should be_ok
    JSON::parse(last_response.body).keys.should == ['name']
  end

  it 'should be able to use a scope that takes arguments' do
    Thing.destroy_all
    Thing.create(:name => 'apple')
    Thing.create(:name => 'banana')
    get '/things:starts_with(a)'
    last_response.should be_ok
    JSON::parse(last_response.body).length.should == 1
  end

  it 'should get a 404 when requesting a non-existent association' do
    thing = Thing.new
    get "/things/#{thing.id}/muppets"
    last_response.should be_not_found
  end

end
