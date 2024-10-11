require 'aws-sdk-s3'

namespace :deploy do
  Rake::Task['deploy:compile_assets'].clear

  desc 'Download or compile assets'
  task :compile_assets => [:set_rails_env] do
    assets_cache_prefix = Nfg::Capistrano::Config.circleci[:parameters][:assets_cache_prefix][:default]
    revision = %x(git --no-pager log -1 --pretty=format:%H)
    branch = fetch(:branch).gsub('/', '_')
    assets_filename="#{assets_cache_prefix}-assets-#{revision}-#{branch}.tar.gz"
    s3_bucket = Nfg::Capistrano::Config.circleci[:parameters][:s3_bucket][:default]
    aws_credentials = Aws::Credentials.new(
      Nfg::Capistrano::Config.api_keys[:aws_access_key_id],
      Nfg::Capistrano::Config.api_keys[:aws_secret_access_key]
    )
    s3 = Aws::S3::Client.new(
      region: ENV.fetch('AWS_REGION', 'us-east-1'),
      credentials: aws_credentials
    )

    begin
      s3.head_object(bucket: s3_bucket.gsub('s3://', ''), key: "assets/#{assets_filename}")
      on release_roles :all do
        execute :s3cmd, "--force get #{s3_bucket}/assets/#{assets_filename} #{shared_path}/public/assets/#{assets_filename}"
        info Airbrussh::Colors.green("Downloaded #{assets_filename} from #{s3_bucket}/assets")
        execute "tar zxvf #{shared_path}/public/assets/#{assets_filename} -C #{shared_path}"
      end
    rescue Aws::S3::Errors::NotFound => e
      on release_roles :all do
        warn Airbrussh::Colors.red("Compiling assets manually since #{assets_filename} does not exist in #{s3_bucket}/assets")
      end
      invoke 'deploy:assets:precompile'
      invoke 'deploy:assets:backup_manifest'
    end
  end
end
