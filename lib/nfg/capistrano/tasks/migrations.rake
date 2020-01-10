namespace :migrations do
  desc 'check if migrations should be run'
  task :check do
    # Reset migration_servers if not running migrations
    if ENV.fetch('MIGRATE') == 'y'
      puts '[migrate:check] Run Migrations'
    else
      puts '[migrate:check] Skip Migrations'
      delete :migration_servers
    end
  end
end
