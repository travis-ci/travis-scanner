# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProcessLogs, type: :service do
  let(:log) { FactoryBot.create(:log) }
  let(:log_ids) { [log.id] }

  subject { ProcessLogs.new(log_ids) }

  describe '#call' do
    context 'when log is queued' do
      let(:log) { FactoryBot.create(:log, scan_status: :queued) }

      it 'starts the scan' do
        expect { subject.call }.to change(ScanTrackerEntry, :count).by(1)
        expect(log.reload.scan_status).to eq('started')
      end
    end

    context 'when log is not queued' do
      it 'does not start the scan' do
        expect { subject.call }.to_not change { ScanTrackerEntry.count }
        expect(log.reload.scan_status).to eq(nil)
      end  
    end
  end
end
