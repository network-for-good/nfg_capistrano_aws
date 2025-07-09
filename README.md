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

cap config:download_config_files_from_s3_remote  # Download configuration files from S3 to remote servers and set linked_files array
cap config:download_config_files_from_s3_local   # Download configuration files from S3 to local /data/config directory

cap migrations:check                             # check if migrations should be run
```

## Configuration File Workflow

The configuration file management is handled by multiple tasks to support different deployment scenarios:

### 1. `config:download_config_files_from_s3_remote` (Part of callback chain)
- **When**: Runs very early in the deployment process (before `deploy:starting`)
- **What**: Downloads configuration files from S3 directly to remote servers at `#{shared_path}/config/`
- **Purpose**: Sets up the `:linked_files` array dynamically based on successfully downloaded files
- **Error handling**: Fails the deployment if required files cannot be downloaded
- **Use case**: Primary task for CI/CD environments and direct remote deployment

### 2. `config:download_config_files_from_s3_local` (Manual task)
- **When**: Run manually when needed
- **What**: Downloads configuration files from S3 to local deployment machine at `/data/config/`
- **Purpose**: Provides local copies of configuration files for development or troubleshooting
- **Error handling**: Fails if required files cannot be downloaded
- **Use case**: Local development or when you need local copies of config files for inspection

### Deployment Flow:
- **Standard/CI deployment**: Only `config:download_config_files_from_s3_remote` runs automatically
- **Local development**: Run `config:download_config_files_from_s3_local` manually when you need local copies

This structure ensures:
- CI/CD environments get streamlined direct remote downloads
- Development environments can work with local copies when needed for debugging
- The deployment fails fast if any required configuration files are missing
- Only successfully downloaded files are included in the linked_files array

## Environment Variables

The following environment variables can be used to customize deployment behavior:

### `DEBUG_S3_PATHS`
- **Purpose**: Enables verbose debugging output for S3 configuration files
- **When to use**: When troubleshooting S3 configuration issues or verifying file paths
- **Output**: Shows application name, config path, and detailed S3 URLs for all configured files
- **Accepted values**: `true`, `1`, `y`, `yes` (case-insensitive)
- **Examples**: 
  - `DEBUG_S3_PATHS=true bundle exec cap production deploy`
  - `DEBUG_S3_PATHS=1 bundle exec cap production deploy`
  - `DEBUG_S3_PATHS=y bundle exec cap production deploy`

### `CI`
- **Purpose**: Indicates deployment is running in a CI/CD environment
- **Effect**: Skips user switching (`as fetch(:app_user)`) during S3 file downloads
- **Value**: Set to `'true'` in CI/CD environments
- **Example**: `CI=true bundle exec cap production deploy`

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
