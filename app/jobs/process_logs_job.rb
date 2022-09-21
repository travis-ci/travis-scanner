class ProcessLogsJob < ApplicationJob
  queue_as :process_logs

  def perform(log_ids)
    ProcessLogsService.call(log_ids)
  end
end
