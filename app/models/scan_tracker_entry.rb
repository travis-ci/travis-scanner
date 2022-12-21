class ScanTrackerEntry < ApplicationRecord
  self.table_name = 'scan_tracker'

  belongs_to :log

  def self.create_entries(log_ids, scan_status)
    scan_tracker_entry_attrs = log_ids.map do |log_id|
      {
        log_id: log_id,
        scan_status: scan_status
      }
    end

    ScanTrackerEntry.create!(scan_tracker_entry_attrs)
  end
end
