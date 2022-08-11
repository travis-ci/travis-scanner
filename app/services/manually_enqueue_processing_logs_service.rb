class ManuallyEnqueueProcessingLogsService < BaseLogsService
  def initialize(params)
    super()

    @log_ids = params[:log_ids]
    @from = params[:from]
    @to = params[:to]
    @force = params[:force]
  end

  def call
    Rails.logger.info('Manually Enqueueing Processing Logs...')

    Travis::Lock.exclusive('manually_enqueue_processing_logs', lock_options) do
      enqueue_processing_logs
    end
  rescue => e
    Rails.logger.error(e.message)
  end

  private

  def enqueue_processing_logs
    logs = Log.where(scan_status: [:ready_for_scan, nil])
    logs = logs.where(id: @log_ids) if @log_ids
    logs = logs.where(created_at: @from..@to) unless @log_ids
    logs = logs.where(scan_status: :done) if @force

    log_ids = logs.pluck(:id)
    return if log_ids.blank?

    logs = Log.where(id: log_ids)

    ApplicationRecord.transaction do
      logs.update_all(
        scan_status: :queued,
        scan_status_updated_at: Time.zone.now
      )

      ScanTrackerEntry.create_entries(log_ids, :queued)

      log_ids.each_slice(Settings.queue_limit) do |log_ids_batch|
        ProcessLogsJob.set(queue: :manually_enqueue_processing_logs)
                      .perform_later(log_ids_batch)
      end
    end
  end
end
