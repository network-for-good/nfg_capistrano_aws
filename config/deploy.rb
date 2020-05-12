set :rvm_type, :system
set :rvm_custom_path, '/usr/local/rvm'
set :rvm_ruby_version, 'ruby-2.3.8@dm'
set :app_user, 'app-user'
set :setup_bucket, -> {"s3-bucket-containing-api-keys"}

set :application, "application-name"
set :repo_url, "git@github.com:my_repo.git"

# Resque
set :resque_environment_task, true
set :workers, { "*" => 2 }
#set :workers, {
  #"*" => 2,
  #"high_priority, evo_syncs, sso_users_api, exports" => 6,
  #"mailers, saved_searches, imports" => 5,
  #"nfg_v4_integration, email_events" => 5,
  #"default, low_priority" => 2
#}
