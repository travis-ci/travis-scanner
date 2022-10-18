module Travis
  module Scanner
    module Plugins
      class Trivy < Base
        def initialize(plugin_scanner_cmd, plugin_config)
          super(plugin_scanner_cmd, plugin_config)

          @scan_plugin_name = 'trivy'
          @json_data = ''
        end

        private

        def get_log_newline_locations(log_id)
          file_path = File.join(@current_run_logs_path, log_id)
          newline_locations = [-1]
          puts file_path
          File.readlines(file_path).each do |line|
            newline_locations << (line.length + newline_locations[-1])
          end
          newline_locations.drop(1)
        end

        def compute_endings(finding)
          newline_locations = get_log_newline_locations finding[:log_id]
          final_scan_findings = []
          lines_to_add = 0
          finding[:scan_findings] = finding[:scan_findings].sort_by { |obj| obj[:start_line] }
          (0..finding[:scan_findings].length - 1).each do |index|
            scan_finding = finding[:scan_findings][index]
            actual_line = scan_finding[:start_line] + lines_to_add - 2
            if index.positive?
              scan_finding_before = finding[:scan_findings][index - 1]
              if actual_line < scan_finding_before[:end_line]
                actual_line = scan_finding_before[:end_line] - 1
                scan_finding[:start_column] -= newline_locations[scan_finding_before[:end_line] - 1] - newline_locations[scan_finding_before[:start_line] - 2]
              end
            end
            line_size = newline_locations[actual_line + 1] - newline_locations[actual_line]
            line_size -= (scan_finding[:start_column] - 1)
            end_column = scan_finding[:size] + 1
            newlines_found = 0
            while line_size < scan_finding[:size]
              end_column = scan_finding[:size] - line_size
              newlines_found += 1
              line_size += (newline_locations[actual_line + newlines_found + 1] - newline_locations[actual_line + newlines_found])
            end
            lines_to_add += newlines_found
            if newlines_found.positive?
              lines_to_add += 1 if line_size == scan_finding[:size]
            else
              end_column += (scan_finding[:start_column] - 1)
            end
            scan_finding[:start_line] = actual_line + 2
            scan_finding[:start_column] = scan_finding[:start_column]
            scan_finding[:end_line] = scan_finding[:start_line] + newlines_found
            scan_finding[:end_column] = end_column
            scan_finding.delete(:column)
            scan_finding.delete(:line)
          end
          finding
        end

        protected

        def compute_command_line(logs_path)
          "#{@plugin_scanner_cmd} fs --security-checks secret -f json #{logs_path}"
        end

        def parse_line(line)
          @json_data << line
        end

        def scan_results
          scan_result = JSON.parse(@json_data)
          return [] unless scan_result.key?('Results')

          results = []
          scan_result['Results'].each do |result|
            next unless result['Class'] == 'secret' || result['Secrets'].empty?

            results << process_result(result)
          end

          results
        rescue JSON::ParserError => e
          Sentry.capture_exception(e)
          Rails.logger.error(e.message)

          []
        end

        def process_result(result)
          finding = {
            log_id: result['Target'],
            scan_findings: []
          }
          scan_findings = {}

          result['Secrets'].each do |secret|
            match_data = secret.dig('Code', 'Lines', 2, 'Content').to_enum(:scan, /\*+/).map { [Regexp.last_match.begin(0) + 1, Regexp.last_match.to_s.length] }
            
            match_data.each do |match|
              scan_findings[[secret['Title'], secret['StartLine'], match.first, match.last]] = {
                name: secret['Title'],
                start_line: secret['StartLine'],
                start_column: match.first,
                size: match.last
              }
            end
          end

          finding[:scan_findings] = scan_findings.values

          compute_endings(finding)
        end
      end
    end
  end
end
