module Travis
  class RemoteLog
    def initialize(job_id, archived_at, archive_verified)
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
      s3_client.put_object(file_options.merge(body: content))
    end

    def store_scan_report(log_id, original_content, report_data)
      s3_client.put_object(
        bucket: Settings.aws.logs_archive_raw_bucket,
        key: "#{log_id}.txt",
        body: original_content
      )

      s3_client.put_object(
        bucket: Settings.aws.logs_archive_bucket,
        key: "scan_reports/#{log_id}.txt",
        body: JSON.dump(report_data)
      )
    end

    private

    def fetch_archived_log_content
      s3_client.get_object(file_options).body.string
    rescue Aws::S3::Errors::NoSuchKey
      ''
    end

    def content_key
      @content_key ||= "jobs/#{@job_id}/log.txt"
    end

    def s3_client
      @s3_client ||= Aws::S3::Client.new(
        region: Settings.aws.region,
        access_key_id: Settings.aws.access_key_id,
        secret_access_key: Settings.aws.secret_access_key
      )
    end

    def file_options
      @file_options ||= {
        bucket: Settings.aws.logs_archive_bucket,
        key: content_key
      }
    end
  end
end
