# Nfg::Capistrano::Aws

This gem assists with the deployment of NFG Ruby applications to AWS. It provides the following cap tasks:
```ruby
cap aws:deploy:confirm_running_instances         # Confirm App Instances and Proceed
cap aws:deploy:fetch_running_instances           # Query Amazon EC2 for Instances tagged with Role: app/app_primary and Running
cap aws:deploy:print_servers                     # Print Server Config
cap aws:deploy:set_app_instances_to_live         # Use fetch_running_instances to set the App Instances
cap aws:deploy:set_app_instances_to_local        # Set the App Instance to localhost
cap aws:maintenance:off                          # Maintenance mode Off
cap aws:maintenance:on                           # Maintenance mode on

cap config:check:get_config_files_from_s3        # Download all configuration files from S3
cap config:check:setup_files_exists_local        # Check Setup files exists in Local
cap config:check:upload_setup_files              # Check Setup files are exists, if not upload files

cap migrations:check                             # check if migrations should be run

cap deploy:compile_assets                        # Download or compile assets
```

## Asset Management

This gem provides a comprehensive approach to prevent asset version conflicts during deployments, particularly useful for beta/staging environments where multiple asset versions might exist.

### Self-Contained Release Architecture

Unlike traditional setups that share assets across releases, this gem configures each release to have its own complete set of assets. This provides several critical benefits:

- **Zero-downtime deployments** - Old releases continue serving their assets during deployment
- **Safe rollbacks** - Each release has its complete asset set available
- **No race conditions** - Multiple servers can deploy simultaneously without conflicts  
- **Atomic deployments** - Each release is completely self-contained

### Asset Compilation

Since each release has its own fresh asset directory, assets are compiled cleanly for each deployment without any conflicts. The gem handles asset compilation through:

#### 1. S3 Asset Cache (Primary Method)
The gem first attempts to download pre-compiled assets from S3 cache, significantly speeding up deployments.

#### 2. Fallback Compilation
If cached assets aren't available, the gem falls back to compiling assets directly on the server.

#### 3. Release Management
Each release maintains its own complete asset set, and old releases are managed through Capistrano's standard `keep_releases` setting rather than asset-specific cleanup.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'nfg-capistrano-aws', require: false
```

And then execute:

    $ bundle

Copy Capfile and config/deploy.rb into your application. Modify deploy.rb with the appropriate values for each setting.

## Files

For capistrano deployment to work, the following files must be present in the codebase:

* Capfile
* config/deploy.rb
* config/deploy/beta.rb
* config/deploy/demo.rb
* config/deploy/production.rb
* config/deploy/development.rb

## Usage
There are three different ways to configure deployments.

### 1. With a manually configured server list
App and worker instances can be manually specifying server directives in the environment config file, e.g. config/deploy/beta.rb. This is the standard method of configurating capistrano. Example:
```
  server "10.0.0.2", user: 'deploy_user', roles: %w{web app app_primary}
  server "10.1.1.2", user: 'deploy_user', roles: %w{resque resque_scheduler worker cron}
```
### 2. With a dynamic server list
If no servers are specified, the gem will use the aws cli gem to dynamically retrieve all servers that have an 'Environment' tag matching the environment passed to cap on the command line, and the'Role' tag containing the values app, app_primary, or worker. These tagging conventions match the tags that our terraform setup adds to ec2 instances during provisioning. IAM credentials are required for this to work.

Both Evo and DM use a dynamic deployment method.

### 3. With individual instance IPs specified on the command line
When running cap commands manually on the management instance, worker and app instance IPs can be specified using WORKER_INSTANCES and APP_INSTANCES environment variables. Multiple IP addresses should be separated by a space, not a comma.

For example, to start resque and resque_scheduler on two worker instances:
```
  > WORKER_INSTANCES="10.1.1.2 10.0.0.2" bundle exec cap production resque:start resque:scheduler:start
```

To deploy to a single app instance:
```
  > APP_INSTANCES="10.3.3.2" bundle exec cap production deploy
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/network-for-good/nfg-capistrano-aws.
