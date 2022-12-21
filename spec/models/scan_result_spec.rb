require 'rails_helper'

RSpec.describe ScanResult do
  let(:scan_result) { create :scan_result }

  it 'belongs to a log' do
    expect(scan_result.log).to be_a(Log)
  end
end
