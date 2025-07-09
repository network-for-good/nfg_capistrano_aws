namespace :config do
  desc 'Download all configuration files from S3'
  task :download_config_files_from_s3 do
    on :local do
      fetch(:s3_config_fies, []).each do |bucket_key, files|
        files.each do |file_config|
          config_file = file_config[:file].respond_to?(:call) ? file_config[:file].call : file_config[:file]
          required = file_config[:required]
          s3_url = "s3://#{bucket_key}/#{config_file}"
          destination = "/data/config/#{File.basename(config_file)}"
          
          info Airbrussh::Colors.green("Downloading: #{s3_url} -> #{destination}")
          
          begin
            execute :aws, "s3api get-object --profile s3-role --bucket #{bucket_key} --key #{config_file} #{destination}", as: fetch(:app_user)
            info Airbrussh::Colors.green("✓ Successfully downloaded #{config_file}")
          rescue => e
            if required
              warn Airbrussh::Colors.red("ERROR! - Failed to download required file: #{s3_url}")
              exit 1
            else
              warn Airbrussh::Colors.yellow("⚠ #{config_file} not found in S3 (optional file, skipping)")
              warn Airbrussh::Colors.yellow("Error: #{e.message}")
            end
          end
        end
      end
    end
  end

  desc 'Upload config files to shared directory on ec2 instances'
  task :upload_config_files_to_shared do
    on roles(:all) do
      fetch(:setup_files, []).each do |file|
        if File.file?(file)
          info Airbrussh::Colors.green("Uploading: #{file} -> #{shared_path}/config/#{File.basename(file)}")
          upload! file, "#{shared_path}/config/#{File.basename(file)}"
        else
          warn Airbrussh::Colors.yellow("⚠ #{file} not found")
        end
      end
    end
  end
end
