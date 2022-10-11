# frozen_string_literal: true

class ScanResult < ApplicationRecord
  validates_presence_of :log_id, :job_id, :owner_id, :owner_type, :content, :issues_found, :token

  belongs_to :job
  belongs_to :log
end
