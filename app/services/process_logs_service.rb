class ProcessLogsService < BaseLogsService
  def initialize(log_ids)
    super()

    @log_ids = log_ids
  end

  def call
    Rails.logger.info("Received log_ids: #{@log_ids.inspect}")

    begin
      Travis::Lock.exclusive('process_logs', lock_options) do
        update_log_entries
      end
    rescue => e
      Rails.logger.error(e.message)
    end
  end

  private

  def update_log_entries
    logs = Log.where(id: @log_ids, scan_status: :queued)
    return unless logs.exists?

    log_ids = logs.pluck(:id)

    ApplicationRecord.transaction do
      logs.update_all(
        scan_status: :started,
        scan_status_updated_at: Time.zone.now
      )

      ScanTrackerEntry.create_entries(log_ids, :started)
    end
  end
end
