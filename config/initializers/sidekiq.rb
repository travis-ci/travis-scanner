# This should not go in a Sidekiq.configure_{client,server} block.

def redis_ssl_params
  @redis_ssl_params ||=
    begin
      return nil unless Settings.redis.ssl

      value = {}
      value[:ca_path] = ENV['REDIS_SSL_CA_PATH'] if ENV['REDIS_SSL_CA_PATH']
      value[:cert] = OpenSSL::X509::Certificate.new(File.read(ENV['REDIS_SSL_CERT_FILE'])) if ENV['REDIS_SSL_CERT_FILE']
      value[:key] = OpenSSL::PKEY::RSA.new(File.read(ENV['REDIS_SSL_KEY_FILE'])) if ENV['REDIS_SSL_KEY_FILE']
      value[:verify_mode] = OpenSSL::SSL::VERIFY_NONE if Settings.ssl_verify == false
      value
    end
end

Sidekiq::Client.reliable_push! unless Rails.env.test?

Sidekiq.configure_server do |config|
  config.redis = {
    url: Settings.redis.url,
    id: nil,
    ssl: Settings.redis.ssl || false,
    ssl_params: redis_ssl_params
  }

  config.reliable_scheduler!
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: Settings.redis.url,
    id: nil,
    ssl: Settings.redis.ssl || false,
    ssl_params: redis_ssl_params
  }
end
