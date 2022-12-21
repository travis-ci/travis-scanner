# This should not go in a Sidekiq.configure_{client,server} block.
Sidekiq::Client.reliable_push! unless Rails.env.test?

Sidekiq.configure_server do |config|
  config.redis = Settings.redis.to_h

  config.reliable_scheduler!
end

Sidekiq.configure_client do |config|
  config.redis = Settings.redis.to_h
end
