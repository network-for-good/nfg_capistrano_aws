namespace :migrations do
  desc 'check if migrations should be run'
  task :check do
    case ENV['MIGRATE']
    when 'y','yes','YES','true'
      puts '[migrate:check] Run Migrations'
      require 'capistrano/rails/migrations'
    else
      puts '[migrate:check] Skip Migrations'
    end
  end
end
