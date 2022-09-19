class ProcessLogBatchJob < ApplicationJob
  queue_as :logs_for_scanning

  def perform(log_ids)
    ProcessLogsService.new(log_ids).call
  end
end
