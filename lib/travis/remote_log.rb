module Travis
  class RemoteLog
    def initialize(job_id, archived_at, archive_verified)
      @job_id = job_id
      @archived_at = archived_at
      @archive_verified = archive_verified
    end

    def archived?
      @archived_at.present? && @archive_verified == true
    end

    def archived_log_content
      @archived_log_content ||= fetch_archived_log_content
    end

    private

    def fetch_archived_log_content
      response = archive_client.get_object(bucket: archive_bucket, key: "jobs/#{@job_id}/log.txt")
      return '' unless response

      response.body.string
    end

    def archive_client
      @archive_client ||= Aws::S3::Client.new
    end

    def archive_bucket
      @archive_bucket ||= [
        ENV['ENVIRONMENT'] == 'staging' ? 'archive-staging' : 'archive',
        ENV['HOST'].split('.')[-2, 2]
      ].flatten.compact.join('.')
    end
  end
end
