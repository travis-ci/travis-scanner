require 'rails_helper'

RSpec.describe Travis::Scanner::Plugins::DetectSecrets do
  subject(:detect_secrets_plugin) do
    described_class.new(Settings.plugins.detect_secrets['cmdline'], Settings.plugins.detect_secrets)
  end

  let!(:log) do
    create :log, scan_status: Log.scan_statuses[:ready_for_scan], content: "content AKIAIOSFODNN7EXAMPLE\nTest"
  end
  let(:log_path) { 'tmp/build_job_logs/1111111111' }
  let(:scan_report_path) { "#{log_path}_scan_report" }

  before do
    FileUtils.mkdir_p(log_path)
    FileUtils.mkdir_p(scan_report_path)
    File.write(File.join(log_path, "#{log.id}.log"), log.content)
  end

  after do
    FileUtils.rm_rf(log_path)
    FileUtils.rm_rf(scan_report_path)
  end

  describe '#scan_results' do
    context 'when there is no parsing error' do
      it 'runs the plugin' do
        detect_secrets_plugin.start(log_path)

        expect(detect_secrets_plugin.result[:scan_results]).to eq(
          [
            {
              log_id: "#{log.id}.log",
              scan_findings: [
                {
                  start_line: 1,
                  name: 'AWS Access Key'
                }
              ]
            }
          ]
        )
      end
    end

    context 'when there is a parsing error' do
      before { allow(JSON).to receive(:parse).and_raise(JSON::ParserError) }

      it 'returns empty result' do
        detect_secrets_plugin.start(log_path)

        expect(detect_secrets_plugin.result[:scan_results]).to eq([])
      end
    end
  end
end
