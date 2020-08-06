namespace :sidekiq do
  desc "start sidekiq"
  task :start do
    on roles(:worker, :scheduler) do
      execute :systemctl, "start sidekiq"
    end
  end

  desc "stop sidekiq"
  task :stop do
    on roles(:worker, :scheduler) do
      execute :systemctl, "start sidekiq"
    end
  end

  desc "restart sidekiq"
  task :restart do
    on roles(:worker, :scheduler) do
      execute :systemctl, "restart sidekiq"
    end
  end

  desc "show sidekiq status"
  task :status do
    on roles(:worker, :scheduler) do
      execute :systemctl, "status sidekiq"
    end
  end
end