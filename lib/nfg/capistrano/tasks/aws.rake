require 'aws-sdk-ec2'
require 'active_support/core_ext/hash'
require 'active_support/hash_with_indifferent_access'

namespace :aws do
  namespace :maintenance do
    desc "Maintenance mode on"
    task :on do
      on roles(:app) do
        file = "/tmp/maintenance.txt"
        unless test("[ -f #{release_path.to_s + file} ]")
          info "Making sure dir exists: #{release_path.to_s + File.dirname(file)}"
          execute :mkdir, '-p', release_path.to_s + File.dirname(file)
          info "Touch path - #{release_path.to_s + file}"
          execute :touch, release_path.to_s + file
        end

      end
    end

    desc "Maintenance mode Off"
    task :off do
      on roles(:app) do
        file = "/tmp/maintenance.txt"
        if test("[ -f #{release_path.to_s + file} ]")
          info "Removing file: #{release_path.to_s + file}"
          execute :rm, release_path.to_s + file
        else
          puts ColorizedString["ERROR! - Can't Remove File. File not exists : #{release_path.to_s + file}"].red
          exit 1
        end
      end
    end

  end

  namespace :deploy do
    desc 'Confirm App Instances and Proceed'
    task :confirm_running_instances do
      puts "\n\n"
      puts ColorizedString["You are deploying to ENV: #{ColorizedString[fetch(:stage).to_s].bold} with Branch/Tag: #{ColorizedString[fetch(:branch).to_s].bold}"].red
      puts "The instance IPs are: #{fetch(:all_instances).map { |i| ["#{i.ip} (#{i.aws_role})"] }.join(', ')}"
    end

    desc "Set the App Instance to localhost"
    task :set_app_instances_to_local do
      server 'localhost', user: fetch(:app_user), roles: %w{web app app_primary}, :primary => true
    end

    desc 'Use fetch_running_instances to set the App Instances'
    task :set_app_instances_to_live do
      app_instances = fetch(:all_instances, []).select { |i| i.aws_role == 'app' }
      worker_instances = fetch(:all_instances, []).select { |i| i.aws_role == 'worker' }

      app_instances.each_with_index do |instance, idx|
        if idx == 0
          server instance.ip, user: fetch(:app_user), roles: %w{web app app_primary}, :primary => true
        else
          server instance.ip, user: fetch(:app_user), roles: %w{web app}
        end
      end

      worker_instances.each_with_index do |instance, idx|
        if idx == 0
          server instance.ip, user: fetch(:app_user), roles: %w{resque_worker resque_scheduler cron_instance}
        else
          server instance.ip, user: fetch(:app_user), roles: %w{resque_worker resque_scheduler}
        end
      end
    end

    desc 'Print Server Config'
    task :print_servers do
      puts ColorizedString['Servers Defined'].bold
      puts '-----------------------'
      %i[app app_primary web resque_worker resque_scheduler cron_instance].each do |r|
        puts ColorizedString["Role: [#{r}]"].bold
        puts roles(r)
      end
      puts "\n"

      puts "Check the list of servers and roles above and confirm."
      set :confirm_running_instances do
        ask("(answer `YES` to deploy):", 'NO')
      end

      unless (fetch(:confirm_running_instances)&.strip == 'YES')
        abort
      end
    end

    desc 'Query Amazon EC2 for Instances tagged with Role: app/app_primary and Running'
    task :fetch_running_instances do
      stage = fetch(:stage)

      # Read Keys here.  Capistrano doesn't have access to Rails.
      config_hash = ActiveSupport::HashWithIndifferentAccess.new(
        YAML::load(ERB.new(IO.read(File.join('config', 'api-keys.yml'))).result)
      )

      config =
        if !config_hash[stage].nil?
          config_hash[:defaults].deep_merge(config_hash[stage])
        else
          config_hash[:defaults]
        end


      # Get instances
      ec2 = Aws::EC2::Resource.new(
        region: ENV.fetch('AWS_REGION', 'us-east-1'),
        access_key_id: config.dig('ec2', 'aws_access_key_id'),
        secret_access_key: config.dig('ec2', 'aws_secret_access_key')
      )

      instances = ec2.instances({filters: [
        {name: 'instance-state-name', values: ['running']},
        {name: 'tag:Role', values: ['app', 'app_primary', 'worker']}
      ]})

      # Debug
      puts "-> To run migrations, add MIGRATE=y to the cap command."
      puts "-> To download and install api-keys.yml, add DOWNLOAD_API_KEYS=y to the cap command."
      puts "-> Example usage:"
      puts "->  bundle exec cap #{rails_env} deploy MIGRATE=y DOWNLOAD_API_KEYS=y"
      puts
      puts ColorizedString["Running Instance in Region: #{ColorizedString[ec2.client.config.region].red}"].bold
      if instances.count == 0
        puts ColorizedString["** NO RUNNING INSTANCES with Role: app/app_primary FOUND.  Aborting **"].red.bold
        abort
      end

      puts "image_id\t\tinstance_type\tstate\tprivate_ip_address\trole"
      puts "--------------------------------------------------------------------------------"
      instances.each do |i|
        role_tag = i.tags.detect { |t| t.key == 'Role' }
        puts "#{i.image_id}\t#{i.instance_type}\t#{i.state.name}\t#{i.private_ip_address}\t\t#{role_tag.value}"
        instance = OpenStruct.new(ip: i.private_ip_address, aws_role: role_tag.value)
        set(:all_instances, fetch(:all_instances, [])).push(instance)
      end
      puts "\nDOWNLOAD_API_KEYS: #{ENV.fetch('DOWNLOAD_API_KEYS', 'n')}"
      puts "MIGRATE: #{ENV.fetch('MIGRATE', 'n')}"
    end
  end
end
