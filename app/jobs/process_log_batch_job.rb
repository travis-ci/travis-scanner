# frozen_string_literal: true

class ProcessLogBatchJob < ApplicationJob
  queue_as :logs_for_scanning

  def perform(log_ids)
    ProcessLogs.new(log_ids).call
  end
end
