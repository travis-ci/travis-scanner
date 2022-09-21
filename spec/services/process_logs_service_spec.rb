require 'rails_helper'

RSpec.describe ProcessLogsService, type: :service do
  subject(:service) { described_class.new(log_ids) }

  let(:log_ids) { [log.id] }

  describe '#call' do
    context 'when there are queued logs' do
      let!(:log) { create :log, scan_status: :queued }

      it 'starts the scan' do
        expect { service.call }.to change(ScanTrackerEntry, :count).by(1)

        log.reload
        expect(log.scan_status).to eq('started')
      end
    end

    context 'when there are no queued logs' do
      let!(:log) { create :log }

      it 'does not start the scan' do
        expect { service.call }.not_to change(ScanTrackerEntry, :count)

        log.reload
        expect(log.scan_status).to be_nil
      end
    end
  end
end
