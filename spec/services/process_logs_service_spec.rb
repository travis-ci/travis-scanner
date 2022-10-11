require 'rails_helper'

RSpec.describe ProcessLogsService, type: :service do
  subject(:service) { described_class.new(log_ids) }

  let(:log_ids) { [log.id] }

  describe '#call' do
    context 'when there are queued logs' do
      let!(:log) { create :log, scan_status: :queued, content: 'content' }

      before { allow(File).to receive(:write).once }

      it 'starts the scan' do
        expect { service.call }.to change(ScanTrackerEntry, :count).by(1)
        expect(File).to have_received(:write)

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

    context 'when process log error occurs' do
      let!(:log) { create :log, scan_status: :queued, content: 'content' }

      before do
        allow(Travis::RemoteLog).to receive(:new).and_raise('error')
        allow(File).to receive(:write).and_call_original
      end

      it 'creates a new error entry' do
        expect { service.call }.to change(ScanTrackerEntry, :count).by(2)
        expect(File).not_to have_received(:write)

        log.reload
        expect(log.scan_status).to eq('error')
      end
    end

    context 'when an error occurs' do
      let!(:log) { create :log, scan_status: :queued }

      before do
        allow(Log).to receive(:where).and_raise('error')
        allow(File).to receive(:write).and_call_original
      end

      it 'does not continue execution' do
        expect { service.call }.not_to change(ScanTrackerEntry, :count)
        expect(File).not_to have_received(:write)

        log.reload
        expect(log.scan_status).to eq('queued')
      end
    end
  end
end
