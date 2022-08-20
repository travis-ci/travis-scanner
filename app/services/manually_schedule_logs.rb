# frozen_string_literal: true

require 'travis/lock'
require 'redlock'

class ManuallyScheduleLogs
  def initialize(force)
    @force = force
  end

  def schedule_logs_by_time_frame(from, to)
    Rails.logger.info("Scheduling logs from=[#{from}] to=[#{to}] with force=[#{@force}]")

    begin
      Travis::Lock.exclusive('schedule_logs', lock_options) do
        log_ids = Log.where.not(:scan_status => filtered_statuses).where(created_at: from..to).pluck(:id)
        enqueue_logs(log_ids)
      end
    rescue Travis::Lock::Redis::LockError => e
      Rails.logger.error(e.message)
    end
  end

  def schedule_logs_by_job_ids(job_ids)
    Rails.logger.info("Scheduling logs by job_ids=[#{job_ids.inspect}] with force=[#{@force}]")

    begin
      Travis::Lock.exclusive('schedule_logs', lock_options) do
        log_ids = Log.where.not(:scan_status => filtered_statuses).where(job_id: job_ids).pluck(:id)
        enqueue_logs(log_ids)
      end
    rescue Travis::Lock::Redis::LockError => e
      Rails.logger.error(e.message)
    end
  end

  private

  def enqueue_logs(log_ids)
    unless log_ids.empty?
      Log.where(id: log_ids).update_all(scan_status: :queued, scan_status_updated_at: Time.now)
      ScanTrackerEntry.create(log_ids.map { |id| { log_id: id } }) do |entry|
        entry.scan_status = :queued
      end
      start_process_log_batch_job(log_ids)
    end
  end

  def filtered_statuses
    filtered_statuses = [:queued, :ready_for_scan, :done, :started, :processing, :finalizing]
    filtered_statuses = [:queued, :ready_for_scan, :started, :processing, :finalizing] if @force
    filtered_statuses
  end

  def start_process_log_batch_job(log_ids)
    log_ids.each_slice(Settings.queue_limit) do |log_ids_chunk|
      ProcessLogBatchJob.set(priority: Settings.low_queue_priority, queue: :low_priority_logs_for_scanning)
                        .perform_later(log_ids_chunk)
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
