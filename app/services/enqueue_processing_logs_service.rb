class EnqueueProcessingLogsService < BaseLogsService
  def call
    Rails.logger.info('Enqueueing Processing Logs...')

    Travis::Lock.exclusive('enqueue_processing_logs', lock_options) do
      enqueue_processing_logs
    end
  rescue => e
    Rails.logger.error(e.message)
    Sentry.capture_exception(e)
  end

  private

  def enqueue_processing_logs
    logs = Log.ready_for_scan
              .order(id: :desc)
              .limit(Settings.queue_limit)

    log_ids = logs.pluck(:id).reverse
    return if log_ids.blank?

    update_logs_status(log_ids, :queued)

    ProcessLogsJob.perform_later(log_ids)
  end
end
