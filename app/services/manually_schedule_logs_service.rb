# frozen_string_literal: true

require 'travis/lock'
require 'redlock'

class ManuallyScheduleLogsService < BaseLogsService
  def initialize(from, to, force, log_ids)
    @from = from
    @to = to
    @force = force
    @log_ids = log_ids
  end

  def call
    begin
      Travis::Lock.exclusive('schedule_logs', lock_options) do
        logs_query = Log.where(scan_status: [:ready_for_scan, nil])
        logs_query.where(scan_status: :done) if @force
        if @log_ids
          logs_query.where(id: @log_ids)
        else
          logs_query.where(created_at: @from..@to)
        end
        log_ids = logs_query.pluck(:id)
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

  def start_process_log_batch_job(log_ids)
    log_ids.each_slice(Settings.queue_limit) do |log_ids_chunk|
      ProcessLogBatchJob.set(priority: Settings.low_queue_priority, queue: :low_priority_logs_for_scanning)
                        .perform_later(log_ids_chunk)
    end
  end
end
