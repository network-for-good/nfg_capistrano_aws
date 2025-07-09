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
      unless fetch(:all_instances).nil?
        puts "\n"
        puts ColorizedString["You are deploying to ENV: #{ColorizedString[fetch(:stage).to_s].bold} with Branch/Tag: #{ColorizedString[fetch(:branch).to_s].bold}"].red
        puts "The instance IPs are: #{fetch(:all_instances).map { |i| ["#{i.ip} (#{i.aws_role})"] }.join(', ')}"
        sleep 5
      end
    end

    desc "Set the App Instance to localhost"
    task :set_app_instances_to_local do
      server 'localhost', user: fetch(:app_user), roles: ENV['CAP_ROLES'].split(','), primary: true
      before 'deploy:starting', 'config:download_config_files_from_s3'
      before 'deploy:check:linked_files', 'config:upload_config_files_to_remote'
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

    desc 'Query Amazon EC2 for Instances tagged with Role: app/app_primary and Running'
    task :fetch_running_instances do
      worker_instances = (ENV['WORKER_INSTANCES'] || '').split
      app_instances = (ENV['APP_INSTANCES'] || '').split
      configured_servers = release_roles(:all)

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
      elsif configured_servers.any?
        before 'deploy:starting', 'config:download_config_files_from_s3'
        before 'deploy:check:linked_files', 'config:upload_config_files_to_remote'
        before 'deploy:migrate', 'migrations:check'
        if configured_servers.first.hostname == 'localhost'
        end
      else
        # Get instances
        ec2 = Aws::EC2::Resource.new(
          region: ENV.fetch('AWS_REGION', 'us-east-1'),
          access_key_id: Nfg::Capistrano::Config.api_keys[:ec2][:aws_access_key_id],
          secret_access_key: Nfg::Capistrano::Config.api_keys[:ec2][:aws_secret_access_key]
        )

        instances = ec2.instances({filters: [
          { name: 'instance-state-name', values: ['running'] },
          { name: 'tag:Environment', values: [fetch(:rails_env)] },
          { name: 'tag:Role', values: ['app', 'app_primary', 'worker'] }
        ]})

        # Debug
        puts "-> To run migrations, add MIGRATE=y to the cap command."
        puts "-> Config files will be automatically downloaded from S3."
        puts "-> Example usage:"
        puts "->   bundle exec cap #{fetch(:rails_env)} deploy MIGRATE=y"
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
        puts "\nMIGRATE: #{ENV.fetch('MIGRATE', 'n')}"

        # Debug S3 Config Files
        puts "\n--- S3 Config Files Debug ---"
        begin
          puts "Application: #{fetch(:application)}"
          app_config_path = fetch(:app_config_path)
          app_config_path = app_config_path.respond_to?(:call) ? app_config_path.call : app_config_path
          puts "App Config Path: #{app_config_path}"
          
          s3_config = fetch(:s3_config_files, {})
          s3_config.each do |bucket_key, files|
            bucket_name = fetch(bucket_key)
            bucket_name = bucket_name.respond_to?(:call) ? bucket_name.call : bucket_name
            puts "#{bucket_key} (#{bucket_name}):"
            files.each do |file_config|
              config_file = file_config[:file].respond_to?(:call) ? file_config[:file].call : file_config[:file]
              status = file_config[:required] ? "REQUIRED" : "optional"
              s3_url = "s3://#{bucket_name}/#{config_file}"
              puts "  - #{s3_url} (#{status})"
            end
          end
        rescue => e
          puts "Error displaying S3 config: #{e.message}"
        end
        puts "--- End S3 Config Debug ---\n"

        before 'deploy:migrate', 'migrations:check'
        before 'deploy:starting', 'config:download_config_files_from_s3'
        before 'deploy:check:linked_files', 'config:upload_config_files_to_remote'
        after 'aws:deploy:fetch_running_instances', 'aws:deploy:confirm_running_instances'
        after 'aws:deploy:confirm_running_instances', 'aws:deploy:set_app_instances_to_live'
      end
    end
  end
end
