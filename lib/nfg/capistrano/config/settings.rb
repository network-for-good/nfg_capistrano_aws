# Default branch is current branch of local
set :branch, (ENV.fetch('BRANCH') do |branch|
  ask("latest tag: #{`git describe --abbrev=0 --tags`.chomp}.\nDefault:", `git rev-parse --abbrev-ref HEAD`.chomp)
end)

# Default value for :setup_files is []
# This setup files expected to be present from where we run cap deploy
set :setup_files, fetch(:setup_files, []).push('/data/config/database.yml', '/data/config/redis.yml', '/data/config/redis-jobs.yml')

# Default value for :linked_files is []
set :linked_files, fetch(:linked_files, []).push('config/database.yml', 'config/redis.yml', 'config/redis-jobs.yml', 'config/api-keys.yml')

# Default value for linked_dirs is []
set :linked_dirs, fetch(:linked_dirs, []).push('node_modules', 'log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'public/system', 'public/assets')

# Restart from current
set :passenger_restart_with_touch, true
set :assets_roles, [:app, :worker, :resque_worker]

set :keep_releases, 5

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure

# capistrano-measure
set :alert_threshold, 10              # default 60 sec
set :warning_threshold, 5             # default 30 sec

