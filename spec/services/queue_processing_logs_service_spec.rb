require 'rails_helper'

RSpec.describe QueueProcessingLogsService, type: :service do
  subject(:service) { described_class }

  describe '#call' do
    context 'when there are ready for scan logs' do
      let!(:log) { create :log, scan_status: :ready_for_scan }

      before { allow(ProcessLogsJob).to receive(:perform_later).with([log.id]).once }

      it 'queue the log for scan' do
        expect { service.call }.to change(ScanTrackerEntry, :count).by(1)
        expect(ProcessLogsJob).to have_received(:perform_later)

        log.reload
        expect(log.scan_status).to eq('queued')
      end
    end

    context 'batch queueing' do
      context 'when there are ready for scan logs' do
        let!(:logs) { create_list(:log, Settings.queue_limit + 1, scan_status: :ready_for_scan) }
        let(:log_ids) { logs.map(&:id).sort.reverse.first(Settings.queue_limit).reverse }

        before { allow(ProcessLogsJob).to receive(:perform_later).with(log_ids).once }

        it 'queue the log for scan' do
          expect { service.call }.to change(ScanTrackerEntry, :count).by(Settings.queue_limit)
          expect(ProcessLogsJob).to have_received(:perform_later)
        end
      end
    end

    context 'when there are no ready for scan logs' do
      let!(:log) { create :log }

      before { allow(ProcessLogsJob).to receive(:perform_later).and_call_original }

      it 'does not queue the log for scan' do
        expect { service.call }.not_to change(ScanTrackerEntry, :count)
        expect(ProcessLogsJob).not_to have_received(:perform_later)

        log.reload
        expect(log.scan_status).to be_nil
      end
    end
  end
end
