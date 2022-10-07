require 'rails_helper'

RSpec.describe ProcessLogsService, type: :service do
  subject(:service) { described_class.new(log_ids) }

  let(:log_ids) { [log.id] }

  describe '#call' do
    context 'when there are queued logs' do
      let!(:log) { create :log, id: 1, scan_status: :queued, content: 'content' }

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
      let!(:log) { create :log, id: 1, scan_status: :queued, content: 'content' }

      before { allow_any_instance_of(Travis::RemoteLog).to receive(:archived?).and_raise("error") }
      before { allow(File).to receive(:write).and_call_original }

      it 'creates a new error entry' do
        expect { service.call }.to change(ScanTrackerEntry, :count).by(2)
        expect(File).to_not have_received(:write)

        log.reload
        expect(log.scan_status).to eq('error')
      end
    end

    context 'when an error occurs' do
      let!(:log) { create :log, scan_status: :queued }

      before { allow(Log).to receive(:where).and_raise("error") }
      before { allow(File).to receive(:write).and_call_original }

      it 'does not continue execution' do
        expect { service.call }.not_to change(ScanTrackerEntry, :count)
        expect(File).to_not have_received(:write)

        log.reload
        expect(log.scan_status).to eq('queued')
      end
    end
  end
end
