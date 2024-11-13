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

    desc 'Check if api-keys should download from S3'
    task :check_apikeys_download_from_s3 do
      case ENV['DOWNLOAD_API_KEYS']
      when 'y','yes','YES','true'
        invoke 'config:check:get_api_keys_from_s3'
      else
        puts '[config:check:check_apikeys_download_from_s3] Skip api-keys.yml file Download from S3'
      end
    end

    desc 'get_api_keys_from_s3'
    task :get_api_keys_from_s3 do
      set :api_key_file, 'config/api-keys.yml'
      on roles(:all) do
        unless execute :aws, "s3api get-object --profile s3-role --bucket #{fetch(:setup_bucket)} --key #{fetch(:api_key_file)} #{shared_path}/#{fetch(:api_key_file)}"
          puts "Error downloading (Maybe there's no api-keys file at s3://#{fetch(:setup_bucket)}/#{fetch(:api_key_file)} )"
        end
      end
    end

  end
end
