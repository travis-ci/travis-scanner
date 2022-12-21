class ReenqueueProcessingLogsService < BaseLogsService
  def call
    Rails.logger.debug('Re-enqueueing Processing Logs...')

    Travis::Lock.exclusive('reenqueue_processing_logs', lock_options) do
      enqueue_processing_logs
    end

    Rails.logger.debug('Re-enqueued Processing Logs...')
  rescue Travis::Lock::Redis::LockError => e
    Rails.logger.warn(e.message)
  rescue => e
    Rails.logger.error(e.message)
    Sentry.capture_exception(e)
  end

  private

  def enqueue_processing_logs
    Log.where(scan_status: [:queued, :started, :processing, :finalizing])
       .where(scan_status_updated_at: ..Settings.requeue_stalled_scans_interval.minutes.ago)
       .update_all(scan_status: :ready_for_scan)
  end
end
