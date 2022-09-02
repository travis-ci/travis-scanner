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
    logs = Log.queued.where(id: @log_ids).to_a

    log_ids = logs.map(&:id)
    return if log_ids.blank?

    FileUtils.mkdir_p(build_job_logs_dir)
    update_logs_status(log_ids, :started)
    process_logs(logs)
  ensure
    FileUtils.rm_rf(build_job_logs_dir)
  end

  def process_logs(logs)
    logs.each(&method(:download_log))
    
    run_scanner(logs)
  end

  def download_log(log)
    Rails.logger.info("Processing log with id=[#{log.id}]")

    remote_log = Travis::RemoteLog.new(log.job_id, log.archived_at, log.archive_verified)
    write_log_to_file(
      log.id,
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

  def write_log_to_file(id, content)
    File.write(File.join(build_job_logs_dir, "#{id}.log"), content) if content.present?
  end
  
  def build_job_logs_dir
    @build_job_logs_dir ||= File.join("tmp/build_job_logs/#{Time.now.to_i}")
  end
  
  def run_scanner(logs)
    log_ids = logs.map(&:id)
    if Dir.entries(build_job_logs_dir).count == 2 # . and ..
      errored_log_ids = Log.error.where(id: log_ids).pluck(:id)
      update_logs_status(log_ids - errored_log_ids, :done)

      return
    end
    
    plugins_result = Travis::Scanner::Runner.new.run(build_job_logs_dir)
    
    affected_log_ids = plugins_result.keys.map(&method(:log_id_from_filename))
    unaffected_log_ids = log_ids - affected_log_ids
    if unaffected_log_ids.present?
      ApplicationRecord.transaction do
        update_logs_status(unaffected_log_ids, :finalizing)
        unaffected_log_ids.each do |log_id|
          ScanResult.create(scan_result_entries) do |entry|
            entry.content = {}
            entry.job_id = grouped_logs[log_id].job_id
            entry.owner_id = 1 # TODO: STUB
            entry.owner_type = 'Repository' # TODO: STUB
            entry.issues_found = 0
            entry.archived = false
            entry.token = 'STUB' # TODO: STUB
          end
        end
        update_logs_status(unaffected_log_ids, :done)
      end

      return
    end

    grouped_logs = logs.each_with_object({}) do |log, memo|
      memo[log.id] = log
    end
    CensorLogsService.new(affected_log_ids, grouped_logs, build_job_logs_dir, plugins_result).call if affected_log_ids.present?
  rescue => e
    Rails.logger.error("An error happened during the plugins execution: #{e.message}\n#{e.backtrace.join("\n")}")
    Sentry.with_scope do |scope|
      scope.set_tags(log_ids: log_ids.join(','))
      Sentry.capture_exception(e)
    end

    update_logs_status(log_ids, :error)
  end
  
  def log_id_from_filename(filename)
    filename.sub('.log', '').to_i
  end
end
