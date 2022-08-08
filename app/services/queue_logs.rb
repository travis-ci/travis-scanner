# frozen_string_literal: true

require 'travis/lock'
require 'redlock'

class QueueLogs
  def call
    log_ids = []
    begin
      Travis::Lock.exclusive('queue_logs', lock_options) do
        logs = Log.where(scan_status: :ready_for_scan).order('id DESC').limit(Settings.queue_limit).pluck(:id)
        logs.update(scan_status: :queued)
      end
    rescue Travis::Lock::Redis::LockError => e
      Rails.logger.error(e.message)
    end

    ProcessLogBatchJob.perform_later(log_ids) unless log_ids.empty?
  end

  private

  def lock_options
    @lock_options ||= {
      strategy: :redis,
      url:      Settings.redis.url,
      retries:  0
    }
  end
end
