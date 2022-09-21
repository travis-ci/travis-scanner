module Travis
  module Scanner
    module Plugins
      class DetectSecrets < Base
        def initialize(plugin_scanner_cmd, plugin_config)
          super(plugin_scanner_cmd, plugin_config)

          @scan_plugin_name = 'detect_secrets'
          @json_data = ''
        end

        protected

        def compute_command_line(logs_path)
          scan_report_file = "#{logs_path}_scan_report/.scan-report"
          [
            "#{@plugin_scanner_cmd} -C #{logs_path} scan --all-files > #{scan_report_file}",
            "cd #{logs_path}",
            "#{@plugin_scanner_cmd} audit --report #{scan_report_file}"
          ].join(' && ')
        end

        def parse_line(line)
          @json_data << line
        end

        def scan_results
          process_results(JSON.parse(@json_data)['results'])
        rescue JSON::ParserError => e
          Sentry.capture_exception(e)
          Rails.logger.error(e.message)

          []
        end

        def process_results(input)
          results = []

          input.each do |json_results|
            scan_findings = []

            json_results['types'].each do |type|
              json_results['lines'].each do |line, _|
                scan_findings << {
                  name: type,
                  start_line: line.to_i
                }
              end
            end

            results << {
              log_id: json_results['filename'],
              scan_findings: scan_findings
            }
          end

          results
        end
      end
    end
  end
end
