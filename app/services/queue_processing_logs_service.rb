class QueueProcessingLogsService < BaseLogsService
  def call
    Rails.logger.info('Queueing logs...')

    begin
      Travis::Lock.exclusive('queue_logs', lock_options) do
        update_log_entries
      end
    rescue => e
      Rails.logger.error(e.message)
    end
  end

  private

  def update_log_entries
    logs = Log.where(scan_status: :ready_for_scan)
              .order(id: :desc)
              .limit(Settings.queue_limit)
    return unless logs.exists?

    log_ids = logs.pluck(:id).reverse

    ApplicationRecord.transaction do
      logs.update_all(
        scan_status: :queued,
        scan_status_updated_at: Time.zone.now
      )

      ScanTrackerEntry.create_entries(log_ids, :queued)

      ProcessLogsJob.perform_later(log_ids)
    end
  end
end
