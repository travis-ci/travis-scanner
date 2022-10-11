require 'rails_helper'

RSpec.describe ProcessLogsService, type: :service do
  subject(:service) { described_class.new(log_ids) }

  let(:log_ids) { [log.id] }

  describe '#call' do
    context 'when there are queued logs' do
      let!(:log) { create :log, scan_status: Log.scan_statuses[:queued], content: "content AKIAIOSFODNN7EXAMPLE\nTest" }
      let(:remote_log) { Travis::RemoteLog.new(log.job_id, log.archived_at, log.archive_verified?) }

      before do
        stub_const('ENV', ENV.to_hash.merge('HOST' => 'travis-ci.org'))
        allow(Travis::RemoteLog).to receive(:new).and_return(remote_log)
        allow(remote_log).to receive(:store_scan_report)
        allow(remote_log).to receive(:update_content)
        allow(File).to receive(:write).and_call_original
      end

      it 'performs the scan' do
        expect { service.call }.to change(ScanTrackerEntry, :count).by(4) # Started, processing, finalizing, and done

        expect(File).to have_received(:write)
        expect(remote_log).to have_received(:store_scan_report)
        expect(remote_log).to have_received(:update_content)
        expect(log.reload.scan_status).to eq(Log.scan_statuses[:done])
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
      let!(:log) { create :log, scan_status: Log.scan_statuses[:queued], content: 'content' }

      before do
        allow(Travis::RemoteLog).to receive(:new).and_raise('error')
        allow(File).to receive(:write).and_call_original
      end

      it 'creates a new error entry' do
        expect { service.call }.to change(ScanTrackerEntry, :count).by(2)

        expect(File).not_to have_received(:write)
        expect(log.reload.scan_status).to eq(Log.scan_statuses[:error])
      end
    end

    context 'when an error occurs' do
      let!(:log) { create :log, scan_status: Log.scan_statuses[:queued] }

      before do
        allow(Log).to receive(:where).and_raise('error')
        allow(File).to receive(:write).and_call_original
      end

      it 'does not continue execution' do
        expect { service.call }.not_to change(ScanTrackerEntry, :count)

        expect(File).not_to have_received(:write)
        expect(log.reload.scan_status).to eq(Log.scan_statuses[:queued])
      end
    end
  end
end
