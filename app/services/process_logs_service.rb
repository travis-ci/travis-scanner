class ProcessLogsService < BaseLogsService
  def initialize(log_ids)
    super()

    @log_ids = log_ids
  end

  def call
    Rails.logger.info("Received log_ids: #{@log_ids.inspect}")

    Travis::Lock.exclusive('process_logs', lock_options) do
      process_log_entries
    end
  rescue => e
    Rails.logger.error(e.message)
    Sentry.capture_exception(e)
  end

  private

  def process_log_entries
    logs = Log.where(id: @log_ids, scan_status: :queued)

    log_ids = logs.pluck(:id)
    return if log_ids.blank?

    logs = Log.where(id: log_ids)

    ApplicationRecord.transaction do
      logs.update_all(
        scan_status: :started,
        scan_status_updated_at: Time.zone.now
      )

      ScanTrackerEntry.create_entries(log_ids, :started)
    end

    process_logs(logs)
  end

  def process_logs(logs)
    logs&.each { |log| process_log(log) }
  end

  def process_log(log)
    Rails.logger.info("Processing log with id=[#{log.id}]")

    remote_log = Travis::RemoteLog.new(log.job_id, log.archive_verified, log.archive_verified)
    write_log_to_file(
      log.id,
      log.job_id,
      remote_log.archived? ? remote_log.archived_log_content : log.content
    )
  rescue => e
    handle_process_log_error(log)

    Rails.logger.error(e.message)
    Sentry.capture_exception(e)
  end

  def handle_process_log_error(log)
    ApplicationRecord.transaction do
      log.update(
        scan_status: :error,
        scan_status_updated_at: Time.zone.now
      )

      ScanTrackerEntry.create_entries([log.id], :error)
    end
  end

  def write_log_to_file(id, job_id, content)
    File.write("tmp/build_job_logs/#{id}-#{job_id}.log", content)
  end
end
