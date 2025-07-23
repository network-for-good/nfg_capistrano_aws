RSpec.describe Nfg::Capistrano::Aws do
  it "has a version number" do
    expect(Nfg::Capistrano::Aws::VERSION).not_to be nil
  end

  it "loads the compile_assets task" do  
    # Verify that the compile_assets task is available
    expect(Rake::Task.task_defined?('deploy:compile_assets')).to be_truthy
  end
end
