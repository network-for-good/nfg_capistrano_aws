namespace :migrations do
  desc 'check if migrations should be run'
  task :check do
    case ENV['MIGRATE']
    when 'y','yes','YES','true'
      puts '[migrate:check] Run Migrations'
      set :migration_role, :app_primary
    else
      puts '[migrate:check] Skip Migrations'
    end
  end
end
