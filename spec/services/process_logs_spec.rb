require 'rails_helper'

RSpec.describe ProcessLogs, type: :service do
  subject { described_class.new(log_ids) }

  let(:log) { create(:log) }
  let(:log_ids) { [log.id] }

  describe '#call' do
    context 'when log is queued' do
      let(:log) { create(:log, scan_status: :queued) }

      it 'starts the scan' do
        expect { subject.call }.to change(ScanTrackerEntry, :count).by(1)
        expect(log.reload.scan_status).to eq('started')
      end
    end

    context 'when log is not queued' do
      it 'does not start the scan' do
        expect { subject.call }.not_to change(ScanTrackerEntry, :count)
        expect(log.reload.scan_status).to be_nil
      end
    end
  end
end
