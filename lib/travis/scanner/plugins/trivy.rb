module Travis
  module Scanner
    module Plugins
      class Trivy < Base
        LineColumn = Struct.new(:start_line, :start_column)

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

          unique_scan_findings = finding[:scan_findings].group_by { |scan_f| LineColumn.new(scan_f[:start_line], scan_f[:start_column]) }
          line_columns = unique_scan_findings.keys.sort_by { |e| [e.start_line, e.start_column] }
          (0..line_columns.length - 1).each do |index|
            line_column = line_columns[index]
            scan_finding = unique_scan_findings[line_column][0]
            actual_line = scan_finding[:start_line] + lines_to_add - 2
            if index.positive?
              scan_finding_before = unique_scan_findings[line_columns[index - 1]][0]
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
            unique_scan_findings[line_column].each do |scan_finding|
              scan_finding[:start_line] = actual_line + 2
              scan_finding[:start_column] = scan_finding[:start_column]
              scan_finding[:end_line] = scan_finding[:start_line] + newlines_found
              scan_finding[:end_column] = end_column
              scan_finding.delete(:column)
              scan_finding.delete(:line)
            end
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
            matching_lines = secret.dig('Code', 'Lines').select {|num| num['FirstCause'] }
            if matching_lines.one?
              match_data = matching_lines.dig(0, 'Content').to_enum(:scan, /\*+/).map { [Regexp.last_match.begin(0) + 1, Regexp.last_match.to_s.length] }
              match_data.each do |match|
                finding[:scan_findings] << {
                  name: secret['Title'],
                  start_column: match.first,
                  start_line: secret['StartLine'],
                  size: match.last
                }
              end
            else
              size = 0
              start_column = nil
              matching_lines.each do |matching_line|
                line_content = matching_line['Content']
                if matching_line['FirstCause']
                  match_data = line_content.to_enum(:scan, /\*+/).map { [Regexp.last_match.begin(0) + 1, Regexp.last_match.to_s.length] }
                  match_data.each do |match|
                    if match.first + match.last == line_content.length + 1
                      start_column = match.first
                      size += match.last
                    end
                  end
                elsif matching_line['LastCause']
                  match_data = line_content.to_enum(:scan, /\*+/).map { [Regexp.last_match.begin(0) + 1, Regexp.last_match.to_s.length] }
                  match_data.each do |match|
                    if match.first == 1
                      size += match.last
                    end
                  end
                elsif matching_line['IsCause']
                  size += line_content.length
                end
              end
              finding[:scan_findings] << {
                name: secret['Title'],
                start_column: match.first,
                start_line: secret['StartLine'],
                size: size
              }
            end
          end

          finding[:scan_findings] = finding[:scan_findings].uniq

          compute_endings(finding)
        end
      end
    end
  end
end
