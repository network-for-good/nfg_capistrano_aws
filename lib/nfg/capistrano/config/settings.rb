# Default branch is current branch of local
set :branch, (ENV.fetch('BRANCH') do |branch|
  ask("latest tag: #{`git describe --abbrev=0 --tags`.chomp}. Default:", `git rev-parse --abbrev-ref HEAD`.chomp)
end)

set :app_instances, ENV['APP_INSTANCES'].split rescue []
set :worker_instances, ENV['WORKER_INSTANCES'].split rescue []

# Default value for :setup_files is []
# This setup files expected to be present from where we run cap deploy
set :setup_files, fetch(:setup_files, []).push('/data/config/database.yml', '/data/config/redis.yml', '/data/config/redis-jobs.yml')

# Default value for :linked_files is []
set :linked_files, fetch(:linked_files, []).push('config/database.yml', 'config/redis.yml', 'config/redis-jobs.yml', 'config/api-keys.yml')

# Default value for linked_dirs is []
set :linked_dirs, fetch(:linked_dirs, []).push('node_modules', 'log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'public/system', 'public/assets')

# If you'd like to capture this output instead, just specify a log file:
set :resque_log_file, "log/resque.log"

# Restart from current
set :passenger_restart_with_touch, true
set :assets_roles, [:app, :resque_worker]

set :keep_releases, 5

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure

# capistrano-whenever
set :whenever_roles, -> { [:app, :web, :cron_instance] }
set :whenever_environment, ->{ "#{fetch(:stage)}" }

# capistrano-measure
set :alert_threshold, 10              # default 60 sec
set :warning_threshold, 5             # default 30 sec

before 'deploy:check:linked_files', 'config:check:upload_setup_files'
before 'config:check:upload_setup_files', 'config:check:setup_files_exists_local'
after 'config:check:upload_setup_files', 'config:check:check_apikeys_download_from_s3'

if ENV['PACKER'] == 'y' || fetch(:stage) == :development
  before 'rvm:hook', 'aws:deploy:set_app_instances_to_local'

elsif fetch(:app_instances) or fetch(:worker_instances)
  print "-> Cron jobs will NOT be installed during manual deployments.\n->\n"

  if fetch(:app_instances)
    fetch(:app_instances).each do |instance|
      print "-> Deploying to app instance #{instance}\n"
      server instance, user: fetch(:app_user), roles: %w(web app)
    end
  end

  if fetch(:worker_instances)
    fetch(:worker_instances).each do |instance|
      print "-> Deploying to worker instance #{instance}\n"
      server instance, user: fetch(:app_user), roles: %w(resque_worker resque_scheduler)
    end
  end
else
  before 'deploy:migrate', 'migrations:check'
  before 'rvm:hook', 'aws:deploy:fetch_running_instances'
  after 'aws:deploy:fetch_running_instances', 'aws:deploy:confirm_running_instances'
  after 'aws:deploy:confirm_running_instances', 'aws:deploy:set_app_instances_to_live'
  after 'aws:deploy:set_app_instances_to_live', 'aws:deploy:print_servers'
end

if defined?(CapistranoResque)
  after "deploy:restart", "resque:restart"
  after "resque:restart", "resque:scheduler:restart"
end
