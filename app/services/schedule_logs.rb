# frozen_string_literal: true

require 'travis/lock'
require 'redlock'

class ScheduleLogs
  def initialize(from, to)
    @from = from
    @to = to
  end

  def call
    from_parsed = Time.parse(@from)
    to_parsed = Time.parse(@to)

    Rails.logger.info("Scheduling logs from=[#{from_parsed}] to=[#{to_parsed}]")

    Log.where.not(:scan_status => [:queued, :ready_for_scan])
       .where(created_at: from_parsed..to_parsed)
       .update_all(scan_status: :ready_for_scan, scan_status_updated_at: Time.now)
  end
end
