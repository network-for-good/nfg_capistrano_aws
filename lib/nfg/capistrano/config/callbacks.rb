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
