# Default branch is current branch of local
set :branch, (ENV.fetch('BRANCH') do |branch|
  ask("latest tag: #{`git describe --abbrev=0 --tags`.chomp}.\nDefault:", `git rev-parse --abbrev-ref HEAD`.chomp)
end)

# Default value for :linked_files is []
# linked_files will be built dynamically based on successfully downloaded S3 config files
set :linked_files, fetch(:linked_files, [])

# Default value for linked_dirs is []
set :linked_dirs, fetch(:linked_dirs, []).push('node_modules', 
                                               'log', 
                                               'tmp/pids', 
                                               'tmp/cache', 
                                               'tmp/sockets', 
                                               'public/system', 
                                               'public/packs')

# Restart from current
set :passenger_restart_with_touch, true
set :assets_roles, [:app, :worker, :resque_worker]

set :keep_releases, 5

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure

# Default S3 configuration path for dynamic config files
set :app_config_path, -> { "terraform/inventory/#{fetch(:application)}-#{fetch(:rails_env)}" }

# Default app config bucket - applications can override this
set :app_config_bucket, "nfg-app-config"

# Default S3 config files configuration
# Applications can override this in their deploy.rb or extend it
set :s3_config_files, {
  :setup_bucket => [
    { file: 'config/api-keys.yml', required: true },
    { file: 'config/master.key', required: false }
  ],
  :app_config_bucket => [
    { file: -> { "#{fetch(:app_config_path)}/database.yml" }, required: true },
    { file: -> { "#{fetch(:app_config_path)}/redis.yml" }, required: true },
    { file: -> { "#{fetch(:app_config_path)}/redis-jobs.yml" }, required: true },
    { file: -> { "#{fetch(:app_config_path)}/cable.yml" }, required: false }
  ]
}

# capistrano-measure
set :alert_threshold, 10              # default 60 sec
set :warning_threshold, 5             # default 30 sec

