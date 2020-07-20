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

cap config:check:check_apikeys_download_from_s3  # Check if api-keys should download from S3
cap config:check:get_api_keys_from_s3            # get_api_keys_from_s3
cap config:check:setup_files_exists_local        # Check Setup files exists in Local
cap config:check:upload_setup_files              # Check Setup files are exists, if not upload files

cap migrations:check                             # check if migrations should be run
```

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

### 1. With a dynamic server list
### 2. With a manually configured server list
### 3. With individual instance IPs specified on the command line

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/network-for-good/nfg-capistrano-aws.
