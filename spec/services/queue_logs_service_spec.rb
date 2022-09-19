require 'rails_helper'

RSpec.describe QueueLogsService, type: :service do
  subject(:service) { described_class.new }

  let(:log) { create(:log, scan_status: :ready_for_scan) }
  let(:log2) { create(:log) }

  describe '#call' do
    before { allow(ProcessLogBatchJob).to receive(:perform_later).with([log.id]).once }

    it 'queues logs ready for scan' do
      expect { service.call }.to change(ScanTrackerEntry, :count).by(1)

      expect(ProcessLogBatchJob).to have_received(:perform_later)
      expect(log.reload.scan_status).to eq('queued')
      expect(log2.reload.scan_status).to be_nil
    end

    context 'batch queueing' do
      before do
        log_ids = logs.sort_by(&:id).reverse!.map(&:id).first(Settings.queue_limit)
        allow(ProcessLogBatchJob).to receive(:perform_later).with(log_ids).once
      end

      let(:logs) { create_list(:log, 300, scan_status: :ready_for_scan) }

      it 'only queues logs in batches' do
        expect { service.call }.to change(ScanTrackerEntry, :count).by(Settings.queue_limit)
        expect(ProcessLogBatchJob).to have_received(:perform_later)
      end
    end
  end
end
