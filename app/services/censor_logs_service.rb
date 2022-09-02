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
      contents = File.read(File.join(@logs_dir, filename)).split("\n")
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

      File.open(File.join(@logs_dir, "#{log_id}_censored.log"), 'w') do |f|
        f.write(contents.join("\n"))
      end

      update_logs_status(@log_ids, :finalizing)
      ApplicationRecord.transaction do
        @log_ids.each do |log_id|
          ScanResult.create(log_id: log_id) do |entry|
            entry.job_id = @grouped_logs[log_id].job_id
            entry.owner_id = 1 # TODO: STUB
            entry.owner_type = 'Repository' # TODO: STUB
            entry.content = @plugins_result["#{log_id}.log"]
            entry.issues_found = entry.content.values.flatten.count
            entry.archived = false
            entry.token = 'STUB' # TODO: STUB
          end
        end
      end

      # TODO: Upload original file backup and scan result to S3
      # TODO: Update the log in DB/S3

      ApplicationRecord.transaction do
        update_logs_status(@log_ids, :done)
        Log.where(id: log_id).update_all(censored: true)
      end
    end
  end

  private

  def update_logs_status(log_ids, status)
    return if log_ids.empty?

    scan_status = Log.scan_statuses[status]
    scan_tracker_entries = log_ids.map { |id| { log_id: id } }
    ApplicationRecord.transaction do
      Log.where(id: log_ids).update_all(scan_status: scan_status, scan_status_updated_at: Time.now)
      ScanTrackerEntry.create(scan_tracker_entries) do |entry|
        entry.scan_status = scan_status
      end
    end
  end
end
