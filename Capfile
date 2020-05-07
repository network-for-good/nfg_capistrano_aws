# Load DSL and set up stages
require "capistrano/setup"

# Include default deployment tasks
require "capistrano/deploy"

# Load the SCM plugin appropriate to your project:
require "capistrano/scm/git"
install_plugin Capistrano::SCM::Git

begin
  require 'capistrano/rvm'
  require 'capistrano/bundler'
  require 'capistrano/linked_files'
  require 'capistrano/rails'
  require 'capistrano/npm'
  require 'capistrano-resque'
  require 'capistrano/passenger'
  require 'capistrano/measure'
  require 'nfg/capistrano/aws'
  require 'whenever/capistrano'
rescue LoadError => e
  print "-> skipping #{e.message.split.last}\n"
end


# Load custom tasks from `lib/capistrano/tasks` if you have any defined
Dir.glob("lib/capistrano/tasks/*.rake").each { |r| import r }
