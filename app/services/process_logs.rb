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
          # TODO - Call log processing logic
          # TODO - Update log information according to the result
        end
      rescue Exception => e
        Sentry.catch_exception(e)
        Rails.logger.error(e.message)
      end
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
