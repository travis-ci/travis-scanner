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

    Rails.logger.info('Manually Enqueued Processing Logs...')
  rescue Travis::Lock::Redis::LockError => e
    Rails.logger.warn(e.message)
  rescue => e
    Rails.logger.error(e.message)
    Sentry.capture_exception(e)
  end

  private

  def enqueue_processing_logs
    logs = Log.default_scoped
    logs = logs.where(scan_status: [:ready_for_scan, nil]) unless @force
    logs = logs.where(id: @log_ids) if @log_ids
    logs = logs.where(created_at: @from..@to) unless @log_ids

    log_ids = logs.pluck(:id)
    return if log_ids.blank?

    update_logs_status(log_ids, :queued)

    log_ids.each_slice(Settings.queue_batch_size) do |batch_log_ids|
      ProcessLogsJob.set(queue: :manually_enqueue_processing_logs)
                    .perform_later(batch_log_ids)
    end
  end
end
