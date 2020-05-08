if ENV['PACKER'] == 'y' || fetch(:stage) == :development
	before 'rvm:hook', 'aws:deploy:set_app_instances_to_local'
else
	before 'rvm:hook', 'aws:deploy:fetch_running_instances'
end


if defined?(CapistranoResque)
  after "deploy:restart", "resque:restart"
  after "resque:restart", "resque:scheduler:restart"
end
