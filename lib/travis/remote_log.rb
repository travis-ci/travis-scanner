module Travis
  class RemoteLog
    def initialize(log_id, job_id, archived_at, archive_verified)
      @log_id = log_id
      @job_id = job_id
      @archived_at = archived_at
      @archive_verified = archive_verified
    end

    def archived?
      @archived_at.present? && @archive_verified
    end

    def archived_log_content
      @archived_log_content ||= fetch_archived_log_content
    end

    def update_content(content)
      s3_client.put_object(logs_archive_file_options.merge(body: content))
    end

    def store_scan_report(original_content, report_data)
      s3_client.put_object(logs_archive_raw_file_options.merge(body: original_content))

      s3_client.put_object(scan_report_file_options.merge(body: JSON.dump(report_data)))
    end

    private

    def fetch_archived_log_content
      s3_client.get_object(logs_archive_file_options).body.string
    rescue Aws::S3::Errors::NoSuchKey
      ''
    end

    def s3_client
      @s3_client ||= Aws::S3::Client.new(
        region: Settings.aws.region,
        access_key_id: Settings.aws.access_key_id,
        secret_access_key: Settings.aws.secret_access_key
      )
    end

    def logs_archive_file_options
      {
        bucket: Settings.aws.logs_archive_bucket,
        key: "jobs/#{@job_id}/log.txt"
      }
    end

    def logs_archive_raw_file_options
      {
        bucket: Settings.aws.logs_archive_raw_bucket,
        key: "logs/#{@log_id}.txt"
      }
    end

    def scan_report_file_options
      {
        bucket: Settings.aws.logs_archive_bucket,
        key: "logs/#{@log_id}_scan_report.txt"
      }
    end
  end
end
