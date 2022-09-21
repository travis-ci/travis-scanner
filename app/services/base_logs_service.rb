class BaseLogsService < ApplicationService
  private

  def lock_options
    @lock_options ||= {
      strategy: :redis,
      url: Settings.redis.url,
      retries: 0
    }
  end
end
