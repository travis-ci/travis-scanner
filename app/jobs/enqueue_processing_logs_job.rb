class EnqueueProcessingLogsJob < ApplicationJob
  def perform
    EnqueueProcessingLogsService.call
  end
end
