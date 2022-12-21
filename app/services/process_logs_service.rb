require 'fileutils'

class ProcessLogsService < BaseLogsService
  def initialize(log_ids)
    super()

    @log_ids = log_ids
  end

  def call
    service_start_time = Time.zone.now
    Rails.logger.debug("Processing logs ids: #{@log_ids.inspect}")

    lock_key = "process_logs_#{OpenSSL::Digest::MD5.hexdigest(@log_ids&.sort.to_s)}"
    Travis::Lock.exclusive(lock_key, lock_options) do
      @log_ids = Log.queued
                    .where(id: @log_ids)
                    .ids
      return if @log_ids.blank?

      update_logs_status(@log_ids, :started)
    end

    process_logs if @log_ids.present?

    Rails.logger.debug("Processed logs ids: #{@log_ids.inspect}. elapsed=#{Time.zone.now - service_start_time}")
  rescue Travis::Lock::Redis::LockError => e
    Rails.logger.warn(e.message)
  rescue => e
    Rails.logger.error(e.message)
    Sentry.with_scope do |scope|
      scope.set_tags(log_ids: @log_ids.join(','))
      Sentry.capture_exception(e)
    end
  end

  private

  def process_logs
    FileUtils.mkdir_p([logs_path, scan_report_path])

    log_attributes = Log.attribute_names - ['content']
    logs = Log.select(log_attributes)
              .where(id: @log_ids)

    Rails.logger.debug("Processing | Preparing logs")
    temporary_substitutions = prepare_logs(logs)
    Rails.logger.debug("Processing | Prepared logs")

    run_scanner(logs, temporary_substitutions)
  ensure
    FileUtils.rm_rf([logs_path, scan_report_path])
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
    remote_log = Travis::RemoteLog.new(log.id, log.job_id, log.archived_at, log.archive_verified?)

    return remote_log.archived_log_content if remote_log.archived?

    Log.select(:content)
       .find_by(id: log.id)&.content
  rescue => e
    update_logs_status([log.id], :error)

    Rails.logger.error(e.message)
    Sentry.capture_exception(e)

    nil
  end

  def write_log_to_file(id, content)
    File.write(File.join(logs_path, "#{id}.log"), content)
  end

  def logs_path
    @logs_path ||= begin
      File.join("/tmp/job_logs/#{Time.zone.now.strftime('%Y-%m-%d_%H-%M-%S-%L')}_#{SecureRandom.hex(5)}")
    end
  end

  def scan_report_path
    "#{logs_path}_scan_report"
  end

  def run_scanner(logs, temporary_substitutions)
    log_ids = logs.map(&:id)

    if Dir.children(logs_path).count.zero?
      errored_log_ids = Log.error
                           .where(id: log_ids)
                           .ids
      update_logs_status(log_ids - errored_log_ids, :done)
      return
    end

    plugins_result = Travis::Scanner::Runner.new.run(logs_path)

    process_plugins_result(logs, temporary_substitutions, plugins_result)
  rescue => e
    handle_scan_errors(e, log_ids)
  end

  def process_plugins_result(logs, temporary_substitutions, plugins_result)
    log_ids = logs.map(&:id)

    ApplicationRecord.transaction do
      update_logs_status(@log_ids, :processing)
    end

    grouped_logs = logs.index_by(&:id)

    affected_log_ids = plugins_result.keys.map { |filename| filename.sub('.log', '').to_i }
    unaffected_log_ids = log_ids - affected_log_ids

    process_unaffected_logs(unaffected_log_ids, grouped_logs) if unaffected_log_ids.present?

    return if affected_log_ids.blank?

    CensorLogsService.call(temporary_substitutions, affected_log_ids, grouped_logs, logs_path, plugins_result)
  end

  def process_unaffected_logs(unaffected_log_ids, grouped_logs)
    ApplicationRecord.transaction do
      update_logs_status(unaffected_log_ids, :finalizing)

      unaffected_log_ids.each do |log_id|
        log = grouped_logs[log_id]

        ScanResult.create!(
          repository_id: log.job&.repository_id,
          job_id: log.job_id,
          log_id: log_id,
          owner_id: log.job&.owner_id,
          owner_type: log.job&.owner_type,
          content: {},
          issues_found: 0,
          archived: false,
          purged_at: nil
        )
      end

      update_logs_status(unaffected_log_ids, :done)
    end
  end

  def handle_scan_errors(e, log_ids)
    Rails.logger.error("An error happened during the plugins execution: #{e.message}\n#{e.backtrace.join("\n")}")
    Sentry.with_scope do |scope|
      scope.set_tags(log_ids: log_ids.join(','))
      Sentry.capture_exception(e)
    end

    update_logs_status(log_ids, :error)
  end
end
