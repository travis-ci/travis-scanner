require 'rails_helper'

RSpec.describe CensorLogsService, type: :service do
  subject(:service) { described_class.new(log_ids, grouped_logs, log_path, plugins_result) }

  let(:log_ids) { [log.id] }
  let(:grouped_logs) { [log].index_by(&:id) }
  let(:log_path) { 'tmp/build_job_logs/1111111111' }
  let(:plugins_result) do
    {
      "#{log.id}.log" => {
        1 => [
          {
            plugin_name: 'trivy',
            finding_name: 'AWS Access Key ID',
            column: 9,
            size: 20
          }
        ]
      }
    }
  end

  before do
    FileUtils.mkdir_p(log_path)
    File.write(File.join(log_path, "#{log.id}.log"), log.content)
  end

  after { FileUtils.rm_rf(log_path) }

  describe '#call' do
    let!(:log) do
      create :log, scan_status: Log.scan_statuses[:ready_for_scan], content: "content AKIAIOSFODNN7EXAMPLE\nTest"
    end
    let(:remote_log) { Travis::RemoteLog.new(log.job_id, log.archived_at, log.archive_verified?) }

    context 'when there are no errors' do
      before do
        allow(Travis::RemoteLog).to receive(:new).and_return(remote_log)
        allow(remote_log).to receive(:store_scan_report)
        allow(remote_log).to receive(:update_content)
      end

      it 'enqueues the log for scan' do
        expect { service.call }.to change(ScanTrackerEntry, :count).by(3)

        expect(remote_log).to have_received(:store_scan_report)
        expect(remote_log).to have_received(:update_content)
        expect(log.reload.content).to eq("content ********************\nTest")
        expect(ScanResult.last.log_id).to eq(log.id)
      end
    end

    context 'when there is an error during storing' do
      before do
        allow(Travis::RemoteLog).to receive(:new).and_return(remote_log)
        allow(remote_log).to receive(:store_scan_report).and_raise(Aws::S3::Errors::Error.new(nil, nil))
      end

      it 'logs the error' do
        expect { service.call }.to change(ScanTrackerEntry, :count).by(3)

        expect(remote_log).to have_received(:store_scan_report)
        expect(log.reload.content).to eq("content AKIAIOSFODNN7EXAMPLE\nTest")
        expect(ScanTrackerEntry.last.log_id).to eq(log.id)
        expect(log.reload.scan_status).to eq(Log.scan_statuses[:error])
      end
    end
  end
end