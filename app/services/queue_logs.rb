require 'travis/lock'

class QueueLogs < ApplicationService
  def call
    begin
      Travis::Lock.exclusive('queue_logs', lock_options) do
        log_ids = Log.where(scan_status: :ready_for_scan).order('id DESC').limit(Settings.queue_limit).pluck(:id)
        if log_ids.present?
          Log.where(id: log_ids).update_all(scan_status: :queued, scan_status_updated_at: Time.zone.now)
          ScanTrackerEntry.create(log_ids.map { |id| { log_id: id } }) do |entry|
            entry.scan_status = :queued
          end
          ProcessLogBatchJob.perform_later(log_ids)
        end
      end
    rescue Travis::Lock::Redis::LockError => e
      Rails.logger.error(e.message)
    end
  end

  private

  def lock_options
    @lock_options ||= {
      strategy: :redis,
      url: Settings.redis.url,
      retries: 0
    }
  end
end
