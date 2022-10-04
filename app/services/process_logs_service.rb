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
    logs_query = Log.where(id: @log_ids, scan_status: :queued)
    log_ids = logs_query.pluck(:id)
    return if log_ids.empty?

    ApplicationRecord.transaction do
      logs_query.update_all(
        scan_status: :started,
        scan_status_updated_at: Time.zone.now
      )

      ScanTrackerEntry.create_entries(log_ids, :started)
    end

    process_logs(logs_query)
  end

  def process_logs(logs)
    logs&.each { |log| process_log(log) }
  end

  def process_log(log)
    Rails.logger.info("Processing log with id=[#{log.id}]")
    remote_log = Travis::RemoteLog.new(remote_log_params(log))
    write_log_to_file(
      remote_log.id,
      remote_log.job_id,
      remote_log.archived? ? remote_log.archived_log_content : remote_log.content
    )
  rescue StandardError => e
    handle_processing_error(e, log)
  end

  def handle_processing_error(exception, log)
    ApplicationRecord.transaction do
      log.scan_status = :error
      log.scan_status_updated_at = Time.zone.now
      log.save

      ScanTrackerEntry.create(log_id: log.id, scan_status: :error)
    end

    Sentry.capture_exception(exception)
    Rails.logger.error(exception.message)
  end

  def remote_log_params(log)
    {
      aggregated_at: log.aggregated_at,
      archive_verified: log.archive_verified,
      archived_at: log.archived_at,
      archiving: log.archiving,
      content: log.content,
      created_at: log.created_at,
      id: log.id,
      job_id: log.job_id,
      purged_at: log.purged_at,
      removed_at: log.removed_at,
      removed_by_id: log.removed_by,
      updated_at: log.updated_at
    }
  end

  def write_log_to_file(id, job_id, content)
    File.write("/srv/app/log/#{id}-#{job_id}.log", content)
  end
end
