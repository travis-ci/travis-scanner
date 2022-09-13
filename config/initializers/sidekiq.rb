Sidekiq.configure_server do |config|
  config.redis = Settings.redis.to_h

  config.logger.level = Logger::DEBUG if Rails.env.development?
end

Sidekiq.configure_client do |config|
  config.redis = Settings.redis.to_h
end
