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
    temporary_substitutions = prepare_logs(logs)
    run_scanner(logs, temporary_substitutions)
  end

  def prepare_logs(logs)
    substitutions = {}
    logs.each do |log|
      content = download_log(log)
      next if content.blank?

      substitutions[log.id] = []
      content = substitute_regexes(content, ["\r\n", "\r"], "\n", substitutions[log.id])
      write_log_to_file(log.id, content)
    end
    substitutions
  end

  def substitute_regexes(content, regs_to_replace, to_str, substitutions)
    regs_to_replace.each do |from_reg|
      substitutions_from_reg = []
      content = replace_in_content(content, from_reg, to_str, substitutions_from_reg)
      substitutions.push([from_reg, substitutions_from_reg])
    end
    content
  end

  def replace_in_content(content, from_reg, to_str, substitutions_of_str)
    r_to_replace = Regexp.new(from_reg)
    content.enum_for(:scan, r_to_replace).map do
      substitutions_of_str.push(Regexp.last_match.offset(0).first)
    end
    content.gsub(r_to_replace, to_str)
  end

  def download_log(log)
    Rails.logger.info("Processing log with id=[#{log.id}]")

    remote_log = Travis::RemoteLog.new(log.id, log.job_id, log.archived_at, log.archive_verified?)

    remote_log.archived? ? remote_log.archived_log_content : log.content
  rescue => e
    update_logs_status([log.id], :error)

    Rails.logger.error(e.message)
    Sentry.capture_exception(e)
    nil
  end

  def write_log_to_file(id, content)
    File.write(File.join(build_job_logs_dir, "#{id}.log"), content)
  end

  def build_job_logs_dir
    @build_job_logs_dir ||= File.join("tmp/build_job_logs/#{Time.now.to_i}")
  end

  def run_scanner(logs, temporary_substitutions)
    log_ids = logs.map(&:id)
    if Dir.entries(build_job_logs_dir).count == 2 # . and ..
      errored_log_ids = Log.error.where(id: log_ids).pluck(:id)
      update_logs_status(log_ids - errored_log_ids, :done)

      return
    end

    process_plugins_result(log_ids, logs, temporary_substitutions, Travis::Scanner::Runner.new.run(build_job_logs_dir))
  rescue => e
    handle_errors(e, log_ids)
  end

  def process_plugins_result(log_ids, logs, temporary_substitutions, plugins_result)
    grouped_logs = logs.index_by(&:id)

    affected_log_ids = plugins_result.keys.map { |filename| filename.sub('.log', '').to_i }
    unaffected_log_ids = log_ids - affected_log_ids
    process_unaffected_logs(unaffected_log_ids, grouped_logs) if unaffected_log_ids.present?
    return if affected_log_ids.blank?

    CensorLogsService.call(temporary_substitutions, affected_log_ids, grouped_logs, build_job_logs_dir, plugins_result)
  end

  def process_unaffected_logs(unaffected_log_ids, grouped_logs)
    ApplicationRecord.transaction do
      update_logs_status(unaffected_log_ids, :finalizing)

      unaffected_log_ids.each do |log_id|
        log = grouped_logs[log_id]
        remote_log = Travis::RemoteLog.new(log.id, log.job_id, log.archived_at, log.archive_verified?)

        ScanResult.create(
          log_id: log_id,
          content: {},
          job_id: log.job_id,
          repository_id: log.job&.repository_id,
          owner_id: log.job&.owner_id,
          owner_type: log.job&.owner_type,
          issues_found: 0,
          archived: remote_log.archived?,
          token: 'STUB' # STANTODO: STUB
        )
      end

      update_logs_status(unaffected_log_ids, :done)
    end
  end

  def handle_errors(e, log_ids)
    Rails.logger.error("An error happened during the plugins execution: #{e.message}\n#{e.backtrace.join("\n")}")
    Sentry.with_scope do |scope|
      scope.set_tags(log_ids: log_ids.join(','))
      Sentry.capture_exception(e)
    end

    update_logs_status(log_ids, :error)
  end
end
