require 'rails_helper'

RSpec.describe QueueLogs, type: :service do
  let(:log) { create(:log, scan_status: :ready_for_scan) }
  let(:log2) { create(:log) }

  describe '#call' do
    it 'queues logs ready for scan' do
      expect(ProcessLogBatchJob).to receive(:perform_later).with([log.id]).once
      expect { subject.call }.to change(ScanTrackerEntry, :count).by(1)

      expect(log.reload.scan_status).to eq('queued')
      expect(log2.reload.scan_status).to be_nil
    end

    context 'batch queueing' do
      let(:logs) { create_list(:log, 300, scan_status: :ready_for_scan) }

      it 'only queues logs in batches' do
        log_ids = logs.sort_by(&:id).reverse!.map(&:id).first(Settings.queue_limit)
        expect(ProcessLogBatchJob).to receive(:perform_later).with(log_ids).once
        expect { subject.call }.to change(ScanTrackerEntry, :count).by(Settings.queue_limit)
      end
    end
  end
end
