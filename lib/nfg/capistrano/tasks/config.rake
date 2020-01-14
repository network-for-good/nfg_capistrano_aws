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
            puts ColorizedString["ERROR! - Cap Deploy Expects Following File to be exists : #{file}"].red
            exit 1
          else
            info ColorizedString["Uploading file to: #{shared_path}/config/#{File.basename(file)}"].green
            upload! file, "#{shared_path}/config/#{File.basename(file)}"
          end
        end
      end
    end

    desc 'Check if api-keys should download from S3'
    task :check_apikeys_download_from_s3 do
      if ENV.fetch('DOWNLOAD_API_KEYS') == 'y'
        invoke 'config:check:get_api_keys_from_s3'
      else
        puts '[config:check:get_api_keys_from_s3] Skip api-keys.yml file Download from S3'
      end
    end

    desc 'get_api_keys_from_s3'
    task :get_api_keys_from_s3 do
      on roles(:all) do
        unless execute :s3cmd, "--force get s3://#{fetch(:setup_bucket)}/#{fetch(:api_key_file)} #{shared_path}/#{fetch(:api_key_file)}"
          puts "Error downloading (Maybe there's no api-keys file at s3://#{fetch(:setup_bucket)}/#{fetch(:api_key_file)} )"
        end
      end
    end

    before 'deploy:check:linked_files', 'config:check:upload_setup_files'
    before 'config:check:upload_setup_files', 'config:check:setup_files_exists_local'
    after 'config:check:upload_setup_files', 'config:check:check_apikeys_download_from_s3'
  end
end
