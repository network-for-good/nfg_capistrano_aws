require 'nfg/capistrano/config/settings'

%w(deploy.rake sidekiq.rake aws.rake config.rake migrations.rake).each do |file|
  load File.expand_path("../tasks/#{file}", __FILE__)
end

require 'nfg/capistrano/config/callbacks'
require 'nfg/capistrano/config'