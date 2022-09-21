require 'rails_helper'

RSpec.describe Travis::Scanner::Plugins::DetectSecrets do
  subject(:detect_secrets_plugin) do
    described_class.new(Settings.plugins.detect_secrets['cmdline'], Settings.plugins.detect_secrets)
  end

  let!(:log) do
    create :log, scan_status: Log.scan_statuses[:ready_for_scan], content: "content AKIAIOSFODNN7EXAMPLE\nTest"
  end
  let(:log_path) { 'tmp/build_job_logs/1111111111' }

  before do
    FileUtils.mkdir_p(log_path)
    File.write(File.join(log_path, "#{log.id}.log"), log.content)
  end

  after { FileUtils.rm_rf(log_path) }

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
                  column: -1,
                  line: 1,
                  name: 'AWS Access Key',
                  size: -1
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
