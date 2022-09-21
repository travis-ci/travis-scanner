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
          "#{@plugin_scanner_cmd} -C #{logs_path} scan --all-files"
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
          input.each do |filename, json_results|
            json_results.each do |result|
              results << {
                log_id: filename,
                scan_findings: [
                  {
                    name: result['type'],
                    line: result['line_number'],
                    column: -1,
                    size: -1
                  }
                ]
              }
            end
          end

          results
        end
      end
    end
  end
end
