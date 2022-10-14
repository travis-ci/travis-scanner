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
        bucket: Settings.original_logs_bucket,
        key: "#{log_id}.txt",
        body: original_content
      )

      s3_client.put_object(
        bucket: archive_bucket,
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
      @s3_client ||= Aws::S3::Client.new
    end

    def archive_bucket
      @archive_bucket ||= [
        Rails.env.staging? ? 'archive-staging' : 'archive',
        ENV['HOST'].split('.')[-2, 2]
      ].flatten.compact.join('.')
    end

    def file_options
      @file_options ||= {
        bucket: archive_bucket,
        key: content_key
      }
    end
  end
end
