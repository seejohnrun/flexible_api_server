require File.dirname(__FILE__) + '/lib/flexible_api_server/version'

spec = Gem::Specification.new do |s|
  
  s.name = 'flexible_api_server'
  s.author = 'John Crepezzi'
  s.add_development_dependency('rspec')
  s.add_development_dependency('sqlite3')
  s.add_development_dependency('rack-test')
  s.add_dependency('activerecord')
  s.add_dependency('sinatra')
  s.add_dependency('sinatra-respond_to')
  s.description = 'Server for exposing Flexible APIs'
  s.summary = 'Server for exposing Flexible APIs'
  s.email = 'john.crepezzi@gmail.com'
  s.files = Dir['lib/**/*.rb']
  s.has_rdoc = false
  s.platform = Gem::Platform::RUBY
  s.require_paths = ['lib']
  s.test_files = Dir.glob('spec/*.rb')
  s.version = FlexibleApiServer::VERSION

end
