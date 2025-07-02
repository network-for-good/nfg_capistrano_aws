namespace :config do
  namespace :check do
    desc 'Check Setup files exists in Local'
    task :setup_files_exists_local do
      on :local do
        fetch(:setup_files, []).each do |file|
          unless  test("[ -f #{file} ]" )
            set(:available_setup_files, []).push(file)
          end
        end
      end
    end

    desc 'Check Setup files are exists, if not upload files'
    task :upload_setup_files do
      on roles(:all) do
        fetch(:setup_files, []).each do |file|
          if fetch(:available_setup_files, []).include?(file)
            puts ColorizedString["ERROR! - Cap Deploy Expects Following File to exist : #{file}"].red
            exit 1
          else
            info ColorizedString["Uploading file to: #{shared_path}/config/#{File.basename(file)}"].green
            upload! file, "#{shared_path}/config/#{File.basename(file)}"
          end
        end
      end
    end

    desc 'Download all configuration files from S3'
    task :get_config_files_from_s3 do
      on roles(:all) do
        s3_config = fetch(:s3_config_files)
        
        puts "\n--- Downloading Config Files from S3 ---"
        s3_config.each do |bucket_key, files|
          bucket_name = fetch(bucket_key)
          bucket_name = bucket_name.respond_to?(:call) ? bucket_name.call : bucket_name
          
          files.each do |file_config|
            config_file = file_config[:file].respond_to?(:call) ? file_config[:file].call : file_config[:file]
            required = file_config[:required]
            s3_url = "s3://#{bucket_name}/#{config_file}"
            destination = "#{shared_path}/config/#{File.basename(config_file)}"
            
            puts "Downloading: #{s3_url} -> #{destination}"
            
            begin
              # Ensure destination directory exists
              execute :mkdir, '-p', File.dirname(destination)
              
              execute :aws, "s3api get-object --profile s3-role --bucket #{bucket_name} --key #{config_file} #{destination}"
              puts ColorizedString["✓ Successfully downloaded #{config_file}"].green
            rescue
              if required
                puts ColorizedString["ERROR! - Failed to download required file: #{s3_url}"].red
                exit 1
              else
                puts ColorizedString["⚠ #{config_file} not found in S3 (optional file, skipping)"].yellow
              end
            end
          end
        end
        puts "--- S3 Download Complete ---\n"
      end
    end

  end
end
