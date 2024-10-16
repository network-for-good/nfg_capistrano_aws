module Nfg
  module Capistrano
    module Config
      def self.circleci
        @circleci_config ||=
          ActiveSupport::HashWithIndifferentAccess.new(
            YAML::load_file('.circleci/config.yml', aliases: true)
          )
      end

      # Read Keys here.  Capistrano doesn't have access to Rails.
      def self.api_keys
        config_hash = ActiveSupport::HashWithIndifferentAccess.new(
          YAML::load(ERB.new(IO.read(File.join('config', 'api-keys.yml'))).result)
        )

        @api_keys_config ||= if !config_hash[fetch(:stage)].nil?
                               config_hash[:defaults].deep_merge(config_hash[fetch(:stage)])
                             else
                               config_hash[:defaults]
                             end
      end
    end
  end
end
