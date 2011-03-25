require 'bundler/setup'
require 'rack/test'

require 'active_record'
ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => 'spec/test.db')

require 'flexible_api'
require File.dirname(__FILE__) + '/../lib/flexible_api_server'
