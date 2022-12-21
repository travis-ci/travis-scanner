require 'rails_helper'

RSpec.describe EnqueueProcessingLogsService, type: :service do
  subject(:service) { described_class }

  before { allow(ProcessLogsJob).to receive(:perform_later).and_call_original }

  describe '#call' do
    context 'when there are ready for scan logs' do
      let!(:log) { create :log, scan_status: Log.scan_statuses[:ready_for_scan] }

      it 'enqueues the log for scan' do
        expect { service.call }.to change(ScanTrackerEntry, :count).by(1)

        expect(ProcessLogsJob).to have_received(:perform_later).with([log.id])
        expect(log.reload.scan_status).to eq(Log.scan_statuses[:queued])
      end
    end

    describe 'batch queueing' do
      context 'when there are ready for scan logs' do
        let!(:logs) { create_list(:log, Settings.queue_limit + 1, scan_status: Log.scan_statuses[:ready_for_scan]) }
        let(:log_ids) { logs.map(&:id).sort.reverse.first(Settings.queue_limit).reverse }

        it 'enqueues the logs for scan' do
          expect { service.call }.to change(ScanTrackerEntry, :count).by(Settings.queue_limit)

          expect(ProcessLogsJob).to have_received(:perform_later).with(log_ids)
          expect(Log.where(id: log_ids).pluck('DISTINCT(scan_status)')).to eq([Log.scan_statuses[:queued]])
        end
      end
    end

    context 'when there are no ready for scan logs' do
      let!(:log) { create :log }

      it 'does not queue the log for scan' do
        expect { service.call }.not_to change(ScanTrackerEntry, :count)

        expect(ProcessLogsJob).not_to have_received(:perform_later)
        expect(log.reload.scan_status).to be_nil
      end
    end

    context 'when an error is raised' do
      let!(:log) { create :log, scan_status: Log.scan_statuses[:ready_for_scan] }
      let(:error) { RuntimeError.new('Test') }

      before { allow(Travis::Lock).to receive(:exclusive).and_raise(error) }

      it 'reports an error' do
        service.call

        expect(Travis::Lock).to have_received(:exclusive)
        expect(ProcessLogsJob).not_to have_received(:perform_later).with([log.id])
        expect(log.reload.scan_status).to eq(Log.scan_statuses[:ready_for_scan])
      end
    end
  end
end
