require 'rails_helper'

RSpec.describe Travis::Scanner::Plugins::Trivy do
  subject(:trivy_plugin) { described_class.new(Settings.plugins.trivy['cmdline'], Settings.plugins.trivy) }

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
        trivy_plugin.start(log_path)

        expect(trivy_plugin.result[:scan_results]).to eq(
          [
            {
              log_id: "#{log.id}.log",
              scan_findings: [
                {
                  column: 9,
                  line: 1,
                  name: 'AWS Access Key ID',
                  size: 20
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
        trivy_plugin.start(log_path)

        expect(trivy_plugin.result[:scan_results]).to eq([])
      end
    end
  end
end
