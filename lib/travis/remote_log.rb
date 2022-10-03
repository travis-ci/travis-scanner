require 'forwardable'
require 'json'

require 'dry-struct'

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

    def job
      @job ||= Job.find(job_id)
    end

    def removed_by
      return nil unless removed_by_id

      @removed_by ||= User.find(removed_by_id)
    end

    def removed?
      !removed_by_id.nil?
    end

    def parts(after: nil, part_numbers: [])
      return solo_part if removed? || aggregated?

      remote.find_parts_by_job_id(
        job_id, after: after, part_numbers: part_numbers
      )
    end

    alias log_parts parts

    def aggregated?
      !!aggregated_at
    end

    def archived?
      !!(!archived_at.nil? && archive_verified?)
    end

    def archived_url(expires: nil)
      @archived_url ||= remote.fetch_archived_url(job_id, expires: expires)
    end

    def archived_log_content
      @archived_log_content ||= remote.fetch_archived_log_content(job_id)
    end

    def to_json(chunked: false, after: nil, part_numbers: [])
      as_json(
        chunked: chunked,
        after: after,
        part_numbers: part_numbers
      ).to_json
    end

    def as_json(chunked: false, after: nil, part_numbers: [])
      ret = {
        'id' => id,
        'job_id' => job_id,
        'type' => 'Log'
      }

      unless removed_at.nil?
        ret['removed_at'] = removed_at.utc.to_s
        ret['removed_by'] = removed_by_name
      end

      if chunked
        ret['parts'] = parts(
          after: after,
          part_numbers: part_numbers
        ).map(&:as_json)
      else
        ret['body'] = log_content
      end

      { 'log' => ret }
    end

    def removed_by_name
      removed_by.name || removed_by.login
    end

    def log_content
      archived_log_content || content
    end

    def remote
      @remote ||= Travis::RemoteLog::Remote.new(platform: platform)
    end

    class ArchiveClient
      def initialize(access_key_id: nil, secret_access_key: nil, bucket_name: nil)
        @bucket_name = bucket_name
        @s3 = Fog::Storage.new(
          aws_access_key_id: access_key_id,
          aws_secret_access_key: secret_access_key,
          provider: 'AWS',
          instrumentor: ActiveSupport::Notifications,
          connection_options: { instrumentor: ActiveSupport::Notifications }
        )
      end

      attr_reader :s3, :bucket_name
      private :s3
      private :bucket_name

      def fetch_archived_url(job_id, expires: nil)
        expires ||= (Time.now.to_i + 30)
        file = fetch_archived(job_id)
        return nil if file.nil?
        return file.public_url if file.public?

        file.url(expires)
      end

      def fetch_archived_log_content(job_id)
        file = fetch_archived(job_id)
        return '' if file.nil?

        file.body.force_encoding('UTF-8')
      end

      private

      def fetch_archived(job_id)
        candidates = s3.directories.get(
          bucket_name,
          prefix: "jobs/#{job_id}/log.txt"
        ).files

        return nil if candidates.empty?

        candidates.first
      end
    end

    class Remote
      extend Forwardable

      def_delegators :archive_client, :fetch_archived_url, :fetch_archived_log_content

      attr_accessor :platform

      def initialize(platform: :default)
        self.platform = platform.to_sym
        clients[self.platform] = create_client
        archive_clients[self.platform] = create_archive_client
      end

      private

      def archive_s3_config
        @archive_s3_config ||= platform_config('log_options.s3').to_h
      end

      def archive_s3_bucket
        @archive_s3_bucket ||= [
          Travis.env == 'staging' ? 'archive-staging' : 'archive',
          platform_config('host').split('.')[-2, 2]
        ].flatten.compact.join('.')
      end

      def create_archive_client
        Travis.logger.info("archive_s3_config.access_key_id: #{archive_s3_config[:access_key_id]}")
        Travis.logger.info("s3_bucket: #{archive_s3_bucket}")
        ArchiveClient.new(
          access_key_id: archive_s3_config[:access_key_id],
          secret_access_key: archive_s3_config[:secret_access_key],
          bucket_name: archive_s3_bucket
        )
      end

      def archive_client
        archive_clients[platform]
      end

      def platform_config(path)
        path = "#{platform}_#{path}" unless platform == :default
        path.split('.').inject(Travis.config) do |config, key|
          config[key]
        end
      end

      def archive_clients
        @archive_clients ||= {}
      end
    end

    private

    def solo_part
      [
        RemoteLogPart.new(
          number: 0,
          content: content,
          final: true
        )
      ]
    end
  end

  class RemoteLogPart < Dry::Struct
    attribute :content, Types::Strict::String.optional
    attribute :final, Types::Strict::Boolean.optional
    attribute :id, Types::Strict::Integer.optional
    attribute :number, Types::Strict::Integer.optional

    def as_json(**_)
      attributes.slice(*%i[content final number])
    end
  end
end
