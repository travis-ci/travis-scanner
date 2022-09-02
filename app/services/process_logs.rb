# frozen_string_literal: true

require 'travis/lock'
require 'redlock'

class ProcessLogs
  def initialize(log_ids)
    @log_ids = log_ids
  end

  def call
    Rails.logger.info("Received log_ids: #{@log_ids.inspect}")

    begin
      Travis::Lock.exclusive('process_logs', lock_options) do
        logs = Log.where(id: @log_ids, scan_status: :queued)
        queued_log_ids = logs.map { |log| { log_id: log.id } }
        ApplicationRecord.transaction do
          logs.update_all(scan_status: :started, scan_status_updated_at: Time.now)
          ScanTrackerEntry.create(queued_log_ids) do |entry|
            entry.scan_status = :started
          end
        end
        process_logs(logs)
      end
    rescue Travis::Lock::Redis::LockError => e
      Rails.logger.error(e.message)
    end
  end

  private

  def process_logs(logs)
    unless logs.empty?
      begin
        logs.each do |log|
          Rails.logger.info("Processing log with id=[#{log.id}] and content=[#{log.content}]")
          remote_log = Travis::RemoteLog.new(:aggregated_at => log.aggregated_at,
                                             :archive_verified => log.archive_verified,
                                             :archived_at => log.archived_at,
                                             :archiving => log.archiving,
                                             :content => log.content,
                                             :created_at => log.created_at,
                                             :id => log.id,
                                             :job_id => log.job_id,
                                             :purged_at => log.purged_at,
                                             :removed_at => log.removed_at,
                                             :removed_by_id => log.removed_by_id,
                                             :updated_at => log.updated_at)
          if remote_log.archived?
            remote_log.archived_log_content
            write_log_to_file(remote_log.id, remote_log.job_id, remote_log.archived_content)
          else
            write_log_to_file(remote_log.id, remote_log.job_id, remote_log.content)
          end
        end
      rescue Exception => e
        Sentry.catch_exception(e)
        Rails.logger.error(e.message)
      end
    end
  end

  def write_log_to_file(id, job_id, content)
    File.open(File.join(__dir__, "../../log/#{id}-#{job_id}")) do |file|
      file.write(content)
    end
  end

  def lock_options
    @lock_options ||= {
      strategy: :redis,
      url: Settings.redis.url,
      retries: 0
    }
  end
end
