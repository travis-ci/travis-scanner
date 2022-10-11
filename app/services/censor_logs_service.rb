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

    @log_ids.each do |log_id|
      filename = "#{log_id}.log"
      contents = File.read(File.join(@logs_dir, filename)).split($/)
      findings = @plugins_result[filename]
      # Shouldn't happen, because we're passing only the affected logs
      next if findings.blank?

      findings.each do |line_number, line_findings|
        applied_line_findings = []
        line_findings.each do |line_finding|
          line_finding = line_finding.with_indifferent_access
          next if line_finding[:column].negative? || applied_line_findings.include?(line_finding[:column])
          applied_line_findings << line_finding[:column]
          start_index = line_finding[:column] - 1
          end_index = start_index + line_finding[:size] - 1
          contents[line_number.to_i - 1][start_index..end_index] = '*' * line_finding[:size]
        end
      end

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

      begin
        remote_log.store_scan_report(
          log_id,
          File.read(File.join(@logs_dir, filename)),
          findings
        )
        censored_content = contents.join($/)
        remote_log.update_content(censored_content)
        ApplicationRecord.transaction do
          log.job&.repository&.update(scan_failed_at: Time.now)
          log.update(content: censored_content, censored: true)
          update_logs_status([log_id], :done)
        end
      rescue Aws::S3::Errors::Error => e
        Rails.logger.error("An error happened while uploading scan results log_id=#{log_id}: #{e.message}")
        Sentry.capture_exception(e)

        update_logs_status([log_id], :error)
      end
    end
  end
end
