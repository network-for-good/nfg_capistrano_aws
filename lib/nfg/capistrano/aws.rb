require 'nfg/capistrano/config/settings'

%w(aws.rake config.rake migrations.rake).each do |file|
  load File.expand_path("../tasks/#{file}", __FILE__)
end

require 'nfg/capistrano/config/callbacks'