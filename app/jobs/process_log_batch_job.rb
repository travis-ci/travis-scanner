# frozen_string_literal: true

class ProcessLogBatchJob < ApplicationJob
  queue_as :logs_for_scanning
  queue_with_priority Settings.default_queue_priority

  def perform(log_ids)
    ProcessLogs.new(log_ids).call
  end
end
