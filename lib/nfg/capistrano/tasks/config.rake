namespace :config do
  desc 'Download all configuration files from S3 locally and set linked_files array'
  task :download_config_files_from_s3 do
    # Initialize empty linked_files array to be populated with successfully downloaded files
    set :linked_files, []
    
    run_locally do
      s3_config = fetch(:s3_config_files, {})
      
      s3_config.each do |bucket_key, files|
        bucket_name = (value = fetch(bucket_key)).respond_to?(:call) ? value.call : value
        
        files.each do |file_config|
          config_file = file_config[:file].respond_to?(:call) ? file_config[:file].call : file_config[:file]
          required = file_config[:required]
          s3_url = "s3://#{bucket_name}/#{config_file}"
          local_destination = "/data/config/#{File.basename(config_file)}"
          
          info Airbrussh::Colors.green("Downloading: #{s3_url} -> #{local_destination}")
          
          begin
            as fetch(:app_user) do
              execute :aws, "s3api get-object --profile s3-role --bucket #{bucket_name} --key #{config_file} #{local_destination}"
            end
            info Airbrussh::Colors.green("✓ Successfully downloaded #{config_file}")
            
            # Add successfully downloaded file to linked_files array
            linked_file_path = "config/#{File.basename(config_file)}"
            current_linked_files = fetch(:linked_files, [])
            current_linked_files.push(linked_file_path) unless current_linked_files.include?(linked_file_path)
            set :linked_files, current_linked_files
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
    end
    
    # Reset, display linked_files array
    run_locally do
      # Reset linked_files to ensure only explicitly downloaded files are included
      # This prevents any legacy configurations from interfering
      downloaded_files = fetch(:linked_files, []).dup
      set :linked_files, []
      set :linked_files, downloaded_files
      
      # Display the dynamically built linked_files array
      linked_files = fetch(:linked_files, [])
      if linked_files.any?
        info Airbrussh::Colors.blue("The following files will be linked during deployment:")
        linked_files.each { |file| info Airbrussh::Colors.blue("  - #{file}") }
      else
        error Airbrussh::Colors.red("ERROR! - No files were successfully downloaded for linking")
        exit 1
      end
    end
  end

  desc 'Upload config files from local to remote servers'
  task :upload_config_files_to_remote do
    run_locally do
      s3_config = fetch(:s3_config_files, {})
      
      s3_config.each do |bucket_key, files|
        files.each do |file_config|
          config_file = file_config[:file].respond_to?(:call) ? file_config[:file].call : file_config[:file]
          required = file_config[:required]
          local_file = "/data/config/#{File.basename(config_file)}"
          
          # Check if file was downloaded locally and upload to remote servers
          if File.exist?(local_file)
            on roles(:all) do
              remote_destination = "#{shared_path}/config/#{File.basename(config_file)}"
              info Airbrussh::Colors.green("Uploading: #{local_file} -> #{remote_destination}")
              upload! local_file, remote_destination
              info Airbrussh::Colors.green("✓ Successfully uploaded #{File.basename(config_file)}")
            end
          elsif required
            warn Airbrussh::Colors.red("ERROR! - Required file #{File.basename(config_file)} was not downloaded")
            exit 1
          end
        end
      end
    end
  end
end
