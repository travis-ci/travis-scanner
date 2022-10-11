# -*- frozen_string_literal: true

module Travis
  module Scanner
    module Plugins
      class Trivy < Base
        def initialize(plugin_scanner_cmd, plugin_config)
          super(plugin_scanner_cmd, plugin_config)

          @scan_plugin_name = 'trivy'
          @json_data = ''
        end

        protected

        def compute_command_line(logs_path)
          "#{@plugin_scanner_cmd} fs --security-checks secret -f json #{logs_path}"
        end

        def parse_line(line)
          @json_data << line
        end

        def get_scan_results
          scan_result = JSON.parse(@json_data)
          return [] unless scan_result.has_key?('Results')

          results = []
          scan_result['Results'].each do |result|
            next unless result['Class'] == 'secret' || result['Secrets'].empty?

            finding = {
              log_id: result['Target'],
              scan_findings: []
            }
            result['Secrets'].each do |secret|
              match_data = secret['Match'].to_enum(:scan, /\*+/).map { [Regexp.last_match.begin(0) + 1, Regexp.last_match.to_s.length] }

              match_data.each do |match|
                finding[:scan_findings] << {
                  name: secret['Title'],
                  line: secret['StartLine'],
                  column: match.first,
                  size: match.last,
                }
              end
            end

            results << finding
          end

          results
        rescue JSON::ParserError => e
          Sentry.capture_exception(e)
          Rails.logger.error(e.message)

          []
        end
      end
    end
  end
end
