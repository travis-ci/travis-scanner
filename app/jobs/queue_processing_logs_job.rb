class QueueProcessingLogsJob < ApplicationJob
  def perform
    QueueProcessingLogsService.call
  end
end
