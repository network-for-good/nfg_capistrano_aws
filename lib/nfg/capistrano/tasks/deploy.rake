require 'aws-sdk-s3'

namespace :deploy do
  Rake::Task['deploy:compile_assets'].clear

  desc 'Download or compile assets'
  task :compile_assets => [:set_rails_env] do
    on release_roles :all do
      assets_cache_prefix = Nfg::Capistrano::Config.circleci[:parameters][:assets_cache_prefix][:default]
      aws_credentials = Aws::Credentials.new(
        Nfg::Capistrano::Config.api_keys[:aws_access_key_id],
        Nfg::Capistrano::Config.api_keys[:aws_secret_access_key]
      )
      s3 = Aws::S3::Client.new(
        region: ENV.fetch('AWS_REGION', 'us-east-1'),
        credentials: aws_credentials
      )

      revision = %x(git --no-pager log -1 --pretty=format:%H)
      branch = fetch(:branch).gsub('/', '_')
      assets_filename="assets/#{assets_cache_prefix}-assets-#{revision}-#{branch}.tar.gz"
      s3_bucket = "nfg-#{fetch(:app_user)}-config"

      begin
        # This will throw a NotFound error if the key doesn't exist
        s3.head_object(bucket: s3_bucket, key: assets_filename)

        info Airbrussh::Colors.green("Downloading #{assets_filename} from #{s3_bucket}")
        execute :s3cmd, "--force get s3://#{s3_bucket}/#{assets_filename} #{shared_path}/public/#{assets_filename}"
        execute "tar zxvf #{shared_path}/public/#{assets_filename} -C #{shared_path}"
      rescue Aws::S3::Errors::NotFound => e
        warn Airbrussh::Colors.red("Compiling assets manually since #{assets_filename} does not exist in #{s3_bucket}")
        invoke 'deploy:assets:precompile'
        invoke 'deploy:assets:backup_manifest'
      end
    end
  end
end
