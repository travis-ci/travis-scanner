require 'fileutils'

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

    FileUtils.mkdir_p(build_job_logs_dir)

    update_logs_status(log_ids, :started)

    process_logs(logs)
  ensure
    FileUtils.rm_rf(build_job_logs_dir)
  end

  def process_logs(logs)
    logs.each(&method(:download_log))
    
    run_scanner
  end

  def download_log(log)
    Rails.logger.info("Processing log with id=[#{log.id}]")

    remote_log = Travis::RemoteLog.new(log.job_id, log.archived_at, log.archive_verified)
    write_log_to_file(
      log.id,
      log.job_id,
      remote_log.archived? ? remote_log.archived_log_content : log.content
    )
  rescue => e
    update_logs_status([log.id], :error)

    Rails.logger.error(e.message)
    Sentry.capture_exception(e)
  end

  def remote_log_params(log)
    {
      id: log.id,
      job_id: log.job_id,
      aggregated_at: log.aggregated_at,
      archive_verified: log.archive_verified,
      archiving: log.archiving,
      archived_at: log.archived_at,
      purged_at: log.purged_at,
      removed_by_id: log.removed_by,
      removed_at: log.removed_at,
      content: log.content,
      created_at: log.created_at,
      updated_at: log.updated_at
    }
  end

  def write_log_to_file(id, job_id, content)
    File.write(File.join(build_job_logs_dir, "#{id}.log"), content) if content.present?
  end
  
  def build_job_logs_dir
    @build_job_logs_dir ||= File.join("tmp/build_job_logs/#{Time.now.to_i}")
  end
  
  def run_scanner
    if Dir.entries(logs_dir).count == 2 # . and ..
      # TODO: Set the right status here
      update_logs_status(log_ids, :ended)

      return
    end
    
    Rails.logger.info JSON.dump(Travis::Scanner::Runner.new.run(logs_dir))
    # TODO: Set the right status here
    update_logs_status(log_ids, :ended)
  rescue => e
    Rails.logger.error("An error happened during the plugins execution: #{e.message}")
    Sentry.with_scope do |scope|
      scope.set_tags(log_ids: log_ids.join(','))
      Sentry.capture_exception(e)
    end
    update_logs_status(log_ids, :error)
  end

  def update_logs_status(log_ids, status)
    ApplicationRecord.transaction do
      Log.where(id: log_ids).update_all(scan_status: status, scan_status_updated_at: Time.now)
      ScanTrackerEntry.create_entries(log_ids, scan_status)
    end
  end
end
