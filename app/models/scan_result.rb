class ScanResult < ApplicationRecord
  belongs_to :repository
  belongs_to :job
  belongs_to :log

  validates :owner_id, :owner_type, :issues_found, presence: true
  validates_exclusion_of :content, in: [nil]
end
