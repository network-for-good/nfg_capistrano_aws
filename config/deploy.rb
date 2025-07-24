set :rvm_type, :system
set :rvm_custom_path, '/usr/local/rvm'
set :rvm_ruby_version, 'ruby-2.3.8@dm'
set :app_user, 'app-user'
set :setup_bucket, -> {"s3-bucket-containing-api-keys"}
set :app_config_bucket, "nfg-app-config"

set :application, "application-name"
set :repo_url, "git@github.com:my_repo.git"
