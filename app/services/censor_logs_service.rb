require 'English'

class CensorLogsService < BaseLogsService
  def initialize(log_ids, grouped_logs, logs_dir, plugins_result)
    super()

    @log_ids = log_ids
    @grouped_logs = grouped_logs
    @logs_dir = logs_dir
    @plugins_result = plugins_result
  end

  def call
    Rails.logger.info("CensorLogsService received log_ids: #{@log_ids.inspect}")

    update_logs_status(@log_ids, :processing)

    @log_ids.each { |log_id| process_log_id(log_id) }
  end

  def process_log_id(log_id)
    filename = "#{log_id}.log"
    findings = @plugins_result[filename]
    # Shouldn't happen, because we're passing only the affected logs
    return if findings.blank?

    contents = File.read(File.join(@logs_dir, filename))
    censored_content = process_findings(contents.split($INPUT_RECORD_SEPARATOR), findings)
                       .join($INPUT_RECORD_SEPARATOR)
    process_result(log_id, findings, contents, censored_content)
  end

  def process_result(log_id, findings, contents, censored_content)
    update_logs_status([log_id], :finalizing)
    log = @grouped_logs[log_id]
    remote_log = Travis::RemoteLog.new(log.job_id, log.archived_at, log.archive_verified?)

    ScanResult.create(
      log_id: log_id,
      job_id: log.job_id,
      owner_id: log.job&.owner_id,
      owner_type: log.job&.owner_type,
      content: findings,
      issues_found: findings.values.flatten.count,
      archived: remote_log.archived?,
      token: 'STUB' # STANTODO: STUB
    )

    store_scan_report(contents, remote_log, log, findings, censored_content)
  end

  def process_findings(contents, findings)
    findings.each do |line_number, line_findings|
      applied_line_findings = []

      line_findings.each do |line_finding|
        line_finding = line_finding.with_indifferent_access
        line_finding_column = line_finding[:column]
        next if line_finding_column.negative? || applied_line_findings.include?(line_finding_column)

        applied_line_findings << line_finding_column
        start_index = line_finding_column - 1
        end_index = start_index + line_finding[:size] - 1
        contents[line_number.to_i - 1][start_index..end_index] = '*' * line_finding[:size]
      end
    end

    contents
  end

  def store_scan_report(contents, remote_log, log, findings, censored_content)
    remote_log.store_scan_report(log.id, contents, findings)
    remote_log.update_content(censored_content)

    ApplicationRecord.transaction do
      log.job&.repository&.update(scan_failed_at: Time.zone.now)
      log.update(content: censored_content, censored: true)
      update_logs_status([log.id], :done)
    end
  rescue Aws::S3::Errors::Error => e
    Rails.logger.error("An error happened while uploading scan results log_id=#{log.id}: #{e.message}")
    Sentry.capture_exception(e)

    update_logs_status([log.id], :error)
  end
end
