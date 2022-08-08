# frozen_string_literal: true

class ProcessLogBatchJob < ApplicationJob
  queue_as :default

  def perform(log_ids)
    ProcessLogs.new(log_ids).call
  end
end
