require 'travis/lock'

class ProcessLogsService < ApplicationService
  def initialize(log_ids)
    super()

    @log_ids = log_ids
  end

  def call
    Rails.logger.info("Received log_ids: #{@log_ids.inspect}")

    begin
      Travis::Lock.exclusive('process_logs', lock_options) do
        update_log_entries
      end
    rescue Travis::Lock::Redis::LockError => e
      Rails.logger.error(e.message)
    end
  end

  private

  def update_log_entries
    logs = Log.where(id: @log_ids, scan_status: :queued)
    queued_log_ids = logs.map { |log| { log_id: log.id } }
    ApplicationRecord.transaction do
      logs.update_all(scan_status: :started, scan_status_updated_at: Time.zone.now) # rubocop:disable Rails/SkipsModelValidations
      ScanTrackerEntry.create(queued_log_ids) do |entry|
        entry.scan_status = :started
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
