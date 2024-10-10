namespace :deploy do
  Rake::Task['deploy:compile_assets'].clear

  desc 'Download or compile assets'
  task :compile_assets => [:set_rails_env] do
    assets_cache_prefix = Nfg::Capistrano::Config.circleci[:parameters][:assets_cache_prefix][:default]
    revision = %x(git --no-pager log -1 --pretty=format:%H)
    branch = fetch(:branch).gsub('/', '_')
    assets_filename="#{assets_cache_prefix}-assets-#{revision}-#{branch}.tar.gz"
    s3_bucket = Nfg::Capistrano::Config.circleci[:parameters][:s3_bucket][:default]

    if %x(s3cmd ls "#{s3_bucket}/#{assets_filename}").blank?
      on release_roles :all do
        warn Airbrussh::Colors.red("Compiling assets manually since #{assets_filename} does not exist in #{s3_bucket}")
      end
      invoke 'deploy:assets:precompile'
      invoke 'deploy:assets:backup_manifest'
    else
      on release_roles :all do
        execute :s3cmd, "--force get s3://#{s3_bucket}/#{assets_filename} #{shared_path}/public/assets/#{assets_filename}"
        info Airbrussh::Colors.green("Downloaded #{assets_filename} from #{s3_bucket}")
        execute "tar zxvf #{shared_path}/public/assets/#{assets_filename} -C #{shared_path}"
      end
    end
  end
end
