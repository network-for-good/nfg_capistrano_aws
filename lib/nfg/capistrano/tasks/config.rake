namespace :config do
  desc 'Download all configuration files from S3 locally and upload to servers'
  task :download_config_files_from_s3 do
    run_locally do
      s3_config = fetch(:s3_config_files, {})
      
      info "\n--- Downloading Config Files from S3 to Local ---"
      
      # Ensure local temp directory exists
      execute :mkdir, '-p', '/data/config'
      
      s3_config.each do |bucket_key, files|
        bucket_name = (value = fetch(bucket_key)).respond_to?(:call) ? value.call : value
        
        files.each do |file_config|
          config_file = file_config[:file].respond_to?(:call) ? file_config[:file].call : file_config[:file]
          required = file_config[:required]
          s3_url = "s3://#{bucket_name}/#{config_file}"
          local_destination = "/data/config/#{File.basename(config_file)}"
          
          info "Downloading: #{s3_url} -> #{local_destination}"
          
          begin
            execute :aws, "s3api get-object --profile s3-role --bucket #{bucket_name} --key #{config_file} #{local_destination}", as: fetch(:app_user)
            info Airbrussh::Colors.green("✓ Successfully downloaded #{config_file}")
          rescue => e
            if required
              warn Airbrussh::Colors.red("ERROR! - Failed to download required file: #{s3_url}")
              warn Airbrussh::Colors.red("Error: #{e.message}")
              exit 1
            else
              warn Airbrussh::Colors.yellow("⚠ #{config_file} not found in S3 (optional file, skipping)")
              next
            end
          end
        end
      end
      
      info "--- Local S3 Download Complete ---\n"
    end
    
    # Now upload the downloaded files to remote servers
    on roles(:all) do
      s3_config = fetch(:s3_config_files, {})
      
      info "\n--- Uploading Config Files to Remote Servers ---"
      
      # Ensure remote config directory exists
      execute :mkdir, '-p', "#{shared_path}/config"
      
      s3_config.each do |bucket_key, files|
        files.each do |file_config|
          config_file = file_config[:file].respond_to?(:call) ? file_config[:file].call : file_config[:file]
          required = file_config[:required]
          local_file = "/data/config/#{File.basename(config_file)}"
          remote_destination = "#{shared_path}/config/#{File.basename(config_file)}"
          
          # Check if file was downloaded locally
          if File.exist?(local_file)
            info "Uploading: #{local_file} -> #{remote_destination}"
            upload! local_file, remote_destination
            info Airbrussh::Colors.green("✓ Successfully uploaded #{File.basename(config_file)}")
          elsif required
            warn Airbrussh::Colors.red("ERROR! - Required file #{File.basename(config_file)} was not downloaded")
            exit 1
          end
        end
      end
      
      info "--- Upload to Remote Servers Complete ---\n"
    end

  end
end
