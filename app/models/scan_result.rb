# frozen_string_literal: true

class ScanResult < ApplicationRecord
  validates :owner_id, :owner_type, :content, :issues_found, :token, presence: true

  belongs_to :job
  belongs_to :log
end
