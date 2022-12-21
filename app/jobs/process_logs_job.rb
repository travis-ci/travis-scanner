class ProcessLogsJob < ApplicationJob
  queue_as :process_logs
  sidekiq_options retry: false

  def perform(log_ids)
    ProcessLogsService.call(log_ids)
  end
end
