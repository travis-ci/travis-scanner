require 'rails_helper'

RSpec.describe ManuallyEnqueueProcessingLogsService, type: :service do
  subject(:service) { described_class.new(params) }

  let(:params) do
    {
      log_ids: [log.id]
    }
  end

  describe '#call' do
    context 'when there are no logs ready for scan' do
      let!(:log) { create :log, scan_status: :done }

      before { allow(ProcessLogsJob).to receive(:perform_later).and_call_original }

      it 'does not queue the log for scan' do
        expect { service.call }.not_to change(ScanTrackerEntry, :count)
        expect(ProcessLogsJob).not_to have_received(:perform_later)

        log.reload
        expect(log.scan_status).to eq('done')
      end
    end

    context 'when there are ready for scan logs' do
      let!(:log) { create :log, scan_status: :ready_for_scan }

      it 'queue the log for scan' do
        expect { service.call }.to change(ScanTrackerEntry, :count).by(1)

        log.reload
        expect(log.scan_status).to eq('queued')
      end
    end

    context 'when an error occurs' do
      let!(:log) { create :log, scan_status: :ready_for_scan }

      before { allow(ProcessLogsJob).to receive(:set).and_raise('error') }

      it 'does not continue execution' do
        expect { service.call }.not_to change(ScanTrackerEntry, :count)

        log.reload
        expect(log.scan_status).to eq('ready_for_scan')
      end
    end
  end
end
