module Types
  include Dry.Types()
end

module Travis
  class RemoteLog < Dry::Struct
    attribute :aggregated_at, Types::Strict::Time.optional
    attribute :archive_verified, Types::Strict::Boolean.defaut(false)
    attribute :archived_at, Types::Strict::Time.optional
    attribute :archiving, Types::Strict::Boolean.defaut(false)
    attribute :content, Types::Strict::String.optional
    attribute :created_at, Types::Strict::Time.optional
    attribute :id, Types::Strict::Integer.optional
    attribute :job_id, Types::Strict::Integer.optional
    attribute :purged_at, Types::Strict::Time.optional
    attribute :removed_at, Types::Strict::Time.optional
    attribute :removed_by_id, Types::Strict::Integer.optional
    attribute :updated_at, Types::Strict::Time.optional

    attr_writer :platform

    def platform
      @platform || :default
    end

    def archived?
      archived_at.present? && archive_verified?
    end

    def archived_log_content
      @archived_log_content ||= fetch_archived_log_content(job_id)
    end

    def fetch_archived_log_content(job_id)
      response = archive_client.get_object({ bucket: archive_bucket, key: "jobs/#{job_id}/log.txt" })
      return '' if file.nil?
      response.body.string
    end

    def archive_client
      @archive_client ||= AWS::S3.new
    end

    def archive_bucket
      @archive_bucket ||= [
        Travis.env == 'staging' ? 'archive-staging' : 'archive',
        platform_config('host').split('.')[-2, 2]
      ].flatten.compact.join('.')
    end

    def platform_config(path)
      path = "#{platform}_#{path}" unless platform == :default
      path.split('.').inject(Travis.config) do |config, key|
        config[key]
      end
    end
  end
end
