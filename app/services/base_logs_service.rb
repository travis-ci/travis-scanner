class BaseLogsService < ApplicationService
  private

  def lock_options
    @lock_options ||= {
      strategy: :redis,
      url: Settings.redis.url,
      retries: 0
    }
  end

  def update_logs_status(log_ids, status)
    scan_status = Log.scan_statuses[status]

    ApplicationRecord.transaction do
      Log.where(id: log_ids)
         .update_all(scan_status: scan_status, scan_status_updated_at: Time.zone.now)
      ScanTrackerEntry.create_entries(log_ids, scan_status)
    end
  end
end
