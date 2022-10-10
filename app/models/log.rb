class Log < ApplicationRecord
  ALL_STATES = %w[
    ready_for_scan
    queued
    started
    error
    processing
    finalizing
    done
  ].freeze

  enum scan_status: ALL_STATES.zip(ALL_STATES).to_h

  belongs_to :job
end
