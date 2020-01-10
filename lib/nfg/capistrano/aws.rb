%w(aws.rake config.rake migrations.rake).each do |file|
  load File.expand_path("../tasks/#{file}", __FILE__)
end