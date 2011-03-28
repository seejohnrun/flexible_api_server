require 'spec/rake/spectask'
require 'lib/flexible_api_server/version'
 
task :build do
  system "gem build flexible_api_server.gemspec"
end

task :release => :build do
  # tag and push
  system "git tag v#{FlexibleApiServer::VERSION}"
  system "git push origin --tags"
  # push the gem
  system "gem push flexible_api_server-#{FlexibleApiServer::VERSION}.gem"
end
