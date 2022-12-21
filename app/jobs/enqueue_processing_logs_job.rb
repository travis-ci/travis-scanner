class EnqueueProcessingLogsJob < ApplicationJob
  def perform
    unless Settings.travis_scanner_enabled
      Rails.logger.error('Travis Scanner is not enabled')
      return
    end

    EnqueueProcessingLogsService.call
  end
end
