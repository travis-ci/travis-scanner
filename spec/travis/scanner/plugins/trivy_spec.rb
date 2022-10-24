require 'rails_helper'

RSpec.describe Travis::Scanner::Plugins::Trivy do
  subject(:trivy_plugin) { described_class.new(Settings.plugins.trivy['cmdline'], Settings.plugins.trivy) }

  let(:content) { "content AKIAIOSFODNN7EXAMPLE\nTest" }
  let!(:log) do
    create :log, scan_status: Log.scan_statuses[:ready_for_scan], content: content
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
                  start_column: 9,
                  start_line: 1,
                  end_column: 29,
                  end_line: 1,
                  name: 'AWS Access Key ID',
                  size: 20
                }
              ]
            }
          ]
        )
      end

      context 'when there is a multi-line private key' do
        let(:private_key) { File.read(File.expand_path('../../../support/files/pkey', __dir__)) }

        context 'and there is another secret on the same line' do
          let(:content) { "example content AKIAIOSFODNN7EXAMPLE #{private_key}\nTest" }
          let(:expected_result) do
            [
              {
                log_id: "#{log.id}.log",
                scan_findings: [
                  {
                    start_line: 1,
                    end_line: 1,
                    name: 'AWS Access Key ID'
                  },
                  {
                    start_line: 1,
                    end_line: 37,
                    name: 'AWS Access Key ID'
                  },
                  {
                    start_line: 1,
                    end_line: 1,
                    name: 'Asymmetric Private Key'
                  },
                  {
                    start_line: 1,
                    end_line: 37,
                    name: 'Asymmetric Private Key'
                  }
                ]
              }
            ]
          end

          it 'is properly detected' do
            trivy_plugin.start(log_path)

            expect(trivy_plugin.result[:scan_results]).to eq(expected_result)
          end
        end

        context 'and it is alone on the line' do
          let(:content) { "content\n#{private_key}" }

          it 'is properly detected' do
            trivy_plugin.start(log_path)

            expect(trivy_plugin.result[:scan_results]).to eq(
              [
                {
                  log_id: "#{log.id}.log",
                  scan_findings: [
                    {
                      start_column: 36,
                      start_line: 2,
                      end_column: 48,
                      end_line: 38,
                      name: 'Asymmetric Private Key',
                      size: 2533
                    }
                  ]
                }
              ]
            )
          end
        end
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
