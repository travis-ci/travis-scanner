class EnqueueProcessingLogsService < BaseLogsService
  def call
    Rails.logger.info('Enqueueing Processing Logs...')

    Travis::Lock.exclusive('enqueue_processing_logs', lock_options) do
      enqueue_processing_logs
    end

    Rails.logger.info('Enqueued Processing Logs...')
  rescue Travis::Lock::Redis::LockError => e
    Rails.logger.warn(e.message)
  rescue => e
    Rails.logger.error(e.message)
    Sentry.capture_exception(e)
  end

  private

  def enqueue_processing_logs
    log_ids = Log.ready_for_scan
                 .order(id: :desc)
                 .limit(Settings.queue_limit)
                 .pluck(:id)
                 .reverse
    return if log_ids.blank?

    update_logs_status(log_ids, :queued)

    log_ids.each_slice(Settings.queue_batch_size) do |batch_log_ids|
      ProcessLogsJob.perform_later(batch_log_ids)
    end
  end
end
