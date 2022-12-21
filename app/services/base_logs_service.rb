class BaseLogsService < ApplicationService
  private

  def lock_options
    @lock_options ||= {
      strategy: :redis,
      url: Settings.redis.url,
      ttl: 30 * 1000,
      retries: 0
    }
  end

  def update_logs_status(log_ids, status)
    scan_status = Log.scan_statuses[status]

    ApplicationRecord.transaction do
      now = Time.zone.now

      update_params = {
        scan_status: scan_status,
        scan_status_updated_at: now
      }
      if status == :queued
        update_params.merge!(
          scan_queued_at: now,
          scan_started_at: nil,
          scan_processing_at: nil,
          scan_finalizing_at: nil,
          scan_ended_at: nil,
        )
      end
      update_params[:scan_started_at] = now if status == :started
      update_params[:scan_processing_at] = now if status == :processing
      update_params[:scan_finalizing_at] = now if status == :finalizing
      update_params[:scan_ended_at] = now if status.in?(%i[done error])

      Log.where(id: log_ids)
         .update_all(update_params)

      ScanTrackerEntry.create_entries(log_ids, scan_status)
    end

    nil
  end
end
