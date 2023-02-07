require 'English'

class CensorLogsService < BaseLogsService
  def initialize(temporary_substitutions, log_ids, grouped_logs, logs_path, plugins_result)
    super()

    @temporary_substitutions = temporary_substitutions
    @log_ids = log_ids
    @grouped_logs = grouped_logs
    @logs_path = logs_path
    @plugins_result = plugins_result
  rescue => e
    Rails.logger.error(e.message)
    Sentry.with_scope do |scope|
      scope.set_tags(log_ids: @log_ids.join(','))
      Sentry.capture_exception(e)
    end
  end

  def call
    service_start_time = Time.zone.now
    Rails.logger.debug("Censoring logs ids: #{@log_ids.inspect}")

    @log_ids.each { |log_id| process_log_id(log_id) }

    Rails.logger.debug("Censored logs ids: #{@log_ids.inspect}. elapsed=#{Time.zone.now - service_start_time}")
  end

  def process_log_id(log_id)
    filename = "#{log_id}.log"
    filepath = File.join(@logs_path, filename)
    findings = @plugins_result&.dig(filename, :scan_findings)
    # Shouldn't happen, because we're passing only the affected logs
    return if findings.blank?
    secrets = @plugins_result&.dig(filename, :scan_secrets)

    Rails.logger.debug("Censoring | Reading file: #{filepath}")
    original_content = File.read(filepath)
    Rails.logger.debug("Censoring | Read file: #{filepath}")

    Rails.logger.debug("Censoring | Splitting original_content")
    content_lines = original_content.split("\n")
    Rails.logger.debug("Censoring | Splited original_content")

    Rails.logger.debug("Censoring | Processing findings")
    censored_content_lines = process_findings(content_lines, findings)
    Rails.logger.debug("Censoring | Processed findings")

    Rails.logger.debug("Censoring | Processing secrets")
    censored_content_lines = process_secrets(censored_content_lines, secrets, findings)
    Rails.logger.debug("Censoring | Processed secrets")

    Rails.logger.debug("Censoring | Joining censored content lines")
    censored_content = censored_content_lines.join("\n")
    Rails.logger.debug("Censoring | Joined censored content lines")

    substitutions = @temporary_substitutions[log_id].reverse
    Rails.logger.debug("Censoring | Reverting substitutions")
    censored_content = revert_substitutions(censored_content, substitutions)
    Rails.logger.debug("Censoring | Reverted substitutions")

    Rails.logger.debug("Censoring | Processing results")
    process_result(log_id, findings, original_content, censored_content)
    Rails.logger.debug("Censoring | Processed results")
  end

  def process_findings(content_lines, findings)
    findings&.each do |start_line, line_findings|
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
                               content_lines[end_line_to_censor.to_i - 1].length + 1
                             end
        unless !end_column_to_censor.nil? && current_end_column < end_column_to_censor
          end_column_to_censor = current_end_column
        end
      end

      (start_line_to_censor - 1..end_line_to_censor - 1).each do |n|
        line_length = content_lines[n].length

        if n == start_line_to_censor - 1
          before = (start_column_to_censor - 2).negative? ? '' : content_lines[n][..start_column_to_censor - 2]
          if n == end_line_to_censor - 1
            end_index = end_column_to_censor - 2
            after = end_column_to_censor - 2 < line_length ? content_lines[n][end_column_to_censor - 1..] : ''
          else
            end_index = -1
            after = ''
          end
          censored = '*' * content_lines[n][start_column_to_censor - 1..end_index].length
          content_lines[n] = before + censored + after
        elsif n == end_line_to_censor - 1
          censored_part_length = content_lines[n][..end_column_to_censor - 2].length
          censored = '*' * [censored_part_length, line_length].min
          after = end_column_to_censor - 2 < line_length ? content_lines[n][end_column_to_censor - 1..] : ''
          content_lines[n] = censored + after
        else
          content_lines[n] = '*' * line_length
        end
      end
    end

    content_lines
  end

  def process_secrets(content_lines, secrets, findings)
    content_lines&.map&.with_index do |content_line, index|
      secrets&.each do |scan_secret|
        secret = scan_secret[:secret]

        if content_line.include?(secret)
          content_line.gsub!(secret, '*' * secret.length)

          scan_secret[:finding_names].each do |finding_name|
            start_line = (index + 1).to_s

            findings[start_line] ||= []
            findings[start_line] << {
              plugin_name: scan_secret[:plugin_name],
              finding_name: finding_name
            }
          end
        end
      end

      content_line
    end

    content_lines
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

  def process_result(log_id, findings, original_content, censored_content)
    update_logs_status([log_id], :finalizing)

    log = @grouped_logs[log_id]

    ScanResult.create!(
      repository_id: log.job&.repository_id,
      job_id: log.job_id,
      log_id: log_id,
      owner_id: log.job&.owner_id,
      owner_type: log.job&.owner_type,
      content: findings,
      issues_found: findings.values.flatten.count,
      archived: true,
      purged_at: nil
    )

    store_scan_report(log, original_content, censored_content, findings)
  end

  def store_scan_report(log, original_content, censored_content, findings)
    remote_log = Travis::RemoteLog.new(log.id, log.job_id, log.archived_at, log.archive_verified?)

    remote_log.store_scan_report(original_content, findings)
    if remote_log.archived?
      remote_log.update_content(censored_content)
    else
      log.update(content: censored_content)
    end

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
