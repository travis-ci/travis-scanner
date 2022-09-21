require 'English'

class CensorLogsService < BaseLogsService
  def initialize(temporary_substitutions, log_ids, grouped_logs, logs_dir, plugins_result)
    super()

    @temporary_substitutions = temporary_substitutions
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

  def revert_substitutions(content, substitutions)
    substitutions.each do |reg, substitutions_of_reg|
      substitutions_of_reg.each do |index|
        if reg.length == 1
          content[index] = reg
        else
          before = content[..index - 1]
          after = (index + 1) < content.length ? content[index + 1..] : ''
          content = before + reg + after
        end
      end
    end
    content
  end

  def process_log_id(log_id)
    filename = "#{log_id}.log"
    findings = @plugins_result[filename]
    # Shouldn't happen, because we're passing only the affected logs
    return if findings.blank?

    content = File.read(File.join(@logs_dir, filename))

    content_lines = content.split("\n")
    censored_content_lines = process_findings(content_lines, findings)
    censored_content = censored_content_lines.join("\n")

    censored_content = revert_substitutions(censored_content, @temporary_substitutions[log_id].reverse)

    process_result(log_id, findings, content, censored_content)
  end

  def process_result(log_id, findings, contents, censored_content)
    update_logs_status([log_id], :finalizing)
    log = @grouped_logs[log_id]
    remote_log = Travis::RemoteLog.new(log.job_id, log.archived_at, log.archive_verified?)

    ScanResult.create(
      log_id: log_id,
      job_id: log.job_id,
      repository_id: log.job&.repository_id,
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
    findings.each do |start_line, line_findings|
      start_line_to_censor = start_line
      start_column_to_censor = nil
      end_line_to_censor = start_line
      end_column_to_censor = nil
      line_findings.each do |line_finding|
        line_finding = line_finding.with_indifferent_access

        if line_finding.key?(:start_column) && (line_finding[:start_column]).positive?
          unless !start_column_to_censor.nil? && line_finding[:start_column] > start_column_to_censor
            start_column_to_censor = line_finding[:start_column]
          end
        else
          start_column_to_censor = 1
        end

        current_end_line = line_finding.key?(:end_line) ? line_finding[:end_line] : start_line_to_censor
        end_line_to_censor = current_end_line unless current_end_line < end_line_to_censor
        current_end_column = if line_finding.key?(:end_column)
                               line_finding[:end_column]
                             else
                               contents[end_line_to_censor.to_i - 1].length + 1
                             end
        unless !end_column_to_censor.nil? && current_end_column < end_column_to_censor
          end_column_to_censor = current_end_column
        end
      end

      (start_line_to_censor - 1..end_line_to_censor - 1).each do |n|
        line_length = contents[n].length

        if n == start_line_to_censor - 1
          before = (start_column_to_censor - 2).negative? ? '' : contents[n][..start_column_to_censor - 2]
          if n == end_line_to_censor - 1
            end_index = end_column_to_censor - 2
            after = end_column_to_censor - 2 < line_length ? contents[n][end_column_to_censor - 1..] : ''
          else
            end_index = -1
            after = ''
          end
          censored = '*' * contents[n][start_column_to_censor - 1..end_index].length
          contents[n] = before + censored + after
        elsif n == end_line_to_censor - 1
          censored_part_length = contents[n][..end_column_to_censor - 2].length
          censored = '*' * [censored_part_length, line_length].min
          after = end_column_to_censor - 2 < line_length ? contents[n][end_column_to_censor - 1..] : ''
          contents[n] = censored + after
        else
          contents[n] = '*' * line_length
        end
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
