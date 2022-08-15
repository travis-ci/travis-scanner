# frozen_string_literal: true

require 'travis/lock'
require 'redlock'

class ScheduleLogs
  def initialize(from, to)
    @from = Time.parse(from)
    @to = Time.parse(to)
  end

  def call
    Rails.logger.info("Scheduling logs from=[#{@from}] to=[#{@to}]")

    Log.where.not(:scan_status => [:queued, :ready_for_scan])
       .where(created_at: @from..@to)
       .update_all(scan_status: :ready_for_scan, scan_status_updated_at: Time.now)
  end
end
