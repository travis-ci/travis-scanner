# frozen_string_literal: true

class ScanTrackerEntry < ApplicationRecord
  self.table_name = 'scan_tracker'

  belongs_to :log
end
