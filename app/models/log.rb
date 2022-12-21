class Log < ApplicationRecord
  belongs_to :job

  ALL_STATES = %w[
    ready_for_scan
    queued
    started
    processing
    finalizing
    done
    error
  ].freeze

  enum scan_status: ALL_STATES.zip(ALL_STATES).to_h
end
