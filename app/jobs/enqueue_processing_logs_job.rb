class EnqueueProcessingLogsJob < ApplicationJob
  queue_as :enqueue_processing_logs
  sidekiq_options retry: false

  def perform
    unless Settings.travis_scanner_enabled
      Rails.logger.error('Travis Scanner is not enabled')
      return
    end

    EnqueueProcessingLogsService.call
  end
end
