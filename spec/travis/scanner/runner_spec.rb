require 'rails_helper'

RSpec.describe Travis::Scanner::Runner do
  subject(:runner) { described_class.new }

  let!(:log) do
    create :log, scan_status: Log.scan_statuses[:ready_for_scan], content: "content AKIAIOSFODNN7EXAMPLE\nTest"
  end
  let(:log_path) { 'tmp/build_job_logs/1111111111' }

  before do
    FileUtils.mkdir_p(log_path)
    File.write(File.join(log_path, "#{log.id}.log"), log.content)
  end

  after { FileUtils.rm_rf(log_path) }

  describe '#run' do
    it 'runs a scan' do
      expect(runner.run(log_path)).to eq(
        "#{log.id}.log" => {
          1 => [
            {
              end_column: 29,
              end_line: 1,
              finding_name: 'AWS Access Key ID',
              plugin_name: 'trivy',
              start_column: 9
            },
            {
              finding_name: 'AWS Access Key',
              plugin_name: 'detect_secrets'
            }
          ]
        }
      )
    end
  end
end
