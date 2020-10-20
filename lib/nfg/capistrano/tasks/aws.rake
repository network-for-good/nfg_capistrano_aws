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
      server 'localhost', user: fetch(:app_user), roles: ENV['CAP_ROLES'].split(','), primary: true
      before 'deploy:check:linked_files', 'config:check:upload_setup_files'
      before 'config:check:upload_setup_files', 'config:check:setup_files_exists_local'
      after 'config:check:upload_setup_files', 'config:check:check_apikeys_download_from_s3'
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
        if instance.name =~ /.*worker.*1$/
          server instance.ip, user: fetch(:app_user), roles: %w{resque_worker resque_scheduler worker cron_instance}
        else
          server instance.ip, user: fetch(:app_user), roles: %w{resque_worker resque_scheduler worker}
        end
      end
    end

    desc 'Print Server Config'
    task :print_servers do
      puts ColorizedString['Servers Defined'].bold
      puts '-----------------------'
      %i[app app_primary web resque_worker resque_scheduler worker cron_instance].each do |r|
        puts ColorizedString["Role: [#{r}]"].bold
        puts roles(r)
      end
      puts "\n"

      puts "Check the list of servers and roles above and confirm."
      set :confirm_running_instances do
        ask("(answer `YES` to deploy):", 'NO')
      end

      unless %w(YES yes y).include?(fetch(:confirm_running_instances).try(:strip))
        abort
      end
    end

    desc 'Query Amazon EC2 for Instances tagged with Role: app/app_primary and Running'
    task :fetch_running_instances do
      worker_instances = (ENV['WORKER_INSTANCES'] || '').split
      app_instances = (ENV['APP_INSTANCES'] || '').split
      configured_servers = fetch(:upload_servers)

      if app_instances.any? or worker_instances.any?
        print "-> Cron jobs will NOT be installed during manual deployments.\n->\n"

        if app_instances
          app_instances.each do |instance|
            print "-> Deploying to app instance #{instance}\n"
            server instance, user: fetch(:app_user), roles: %w(web app)
          end
        end

        if worker_instances
          worker_instances.each do |instance|
            print "-> Deploying to worker instance #{instance}\n"
            server instance, user: fetch(:app_user), roles: %w(resque_worker resque_scheduler worker)
          end
        end
      elsif configured_servers.present?
        before 'deploy:symlink:linked_files', 'config:check:check_apikeys_download_from_s3'
        before 'deploy:migrate', 'migrations:check'
        if configured_servers.first.hostname == 'localhost'
        end
      else
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
          access_key_id: config[:ec2][:aws_access_key_id],
          secret_access_key: config[:ec2][:aws_secret_access_key]
        )

        instances = ec2.instances({filters: [
          { name: 'instance-state-name', values: ['running'] },
          { name: 'tag:Environment', values: [fetch(:rails_env)] },
          { name: 'tag:Role', values: ['app', 'app_primary', 'worker'] }
        ]})

        # Debug
        puts "-> To run migrations, add MIGRATE=y to the cap command."
        puts "-> To download and install api-keys.yml, add DOWNLOAD_API_KEYS=y to the cap command."
        puts "-> Example usage:"
        puts "->  bundle exec cap #{fetch(:rails_env)} deploy MIGRATE=y DOWNLOAD_API_KEYS=y"
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
          name_tag = i.tags.detect { |t| t.key == 'Name' }
          puts "#{i.image_id}\t#{i.instance_type}\t#{i.state.name}\t#{i.private_ip_address}\t\t#{role_tag.value}"
          instance = OpenStruct.new(ip: i.private_ip_address, aws_role: role_tag.value, name: name_tag.value)
          set(:all_instances, fetch(:all_instances, [])).push(instance)
        end
        puts "\nDOWNLOAD_API_KEYS: #{ENV.fetch('DOWNLOAD_API_KEYS', 'n')}"
        puts "MIGRATE: #{ENV.fetch('MIGRATE', 'n')}"

        before 'deploy:migrate', 'migrations:check'
        after 'aws:deploy:fetch_running_instances', 'aws:deploy:confirm_running_instances'
        after 'aws:deploy:confirm_running_instances', 'aws:deploy:set_app_instances_to_live'
        after 'aws:deploy:set_app_instances_to_live', 'aws:deploy:print_servers'
        before 'deploy:check:linked_files', 'config:check:upload_setup_files'
        before 'config:check:upload_setup_files', 'config:check:setup_files_exists_local'
        after 'config:check:upload_setup_files', 'config:check:check_apikeys_download_from_s3'
      end
    end
  end
end
