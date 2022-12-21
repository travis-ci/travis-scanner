class ManuallyEnqueueProcessingLogsService < BaseLogsService
  def initialize(params)
    super()

    @log_ids = params[:log_ids]
    @from = params[:from]
    @to = params[:to]
    @force = params[:force]
  end

  def call
    Rails.logger.debug('Manually Enqueueing Processing Logs...')

    Travis::Lock.exclusive('manually_enqueue_processing_logs', lock_options) do
      enqueue_processing_logs
    end

    Rails.logger.debug('Manually Enqueued Processing Logs...')
  rescue Travis::Lock::Redis::LockError => e
    Rails.logger.warn(e.message)
  rescue => e
    Rails.logger.error(e.message)
    Sentry.with_scope do |scope|
      scope.set_tags(log_ids: @log_ids.join(','))
      Sentry.capture_exception(e)
    end
  end

  private

  def enqueue_processing_logs
    logs = Log.default_scoped
    logs = logs.where(scan_status: nil) unless @force
    logs = logs.where(created_at: @from..@to) unless @log_ids
    logs = logs.where(id: @log_ids) if @log_ids

    log_ids = logs.ids
    return if log_ids.blank?

    update_logs_status(log_ids, :queued)

    log_ids.each_slice(Settings.queue_batch_size) do |batch_log_ids|
      ProcessLogsJob.set(queue: :manually_enqueued_process_logs)
                    .perform_later(batch_log_ids)
    end
  end
end
