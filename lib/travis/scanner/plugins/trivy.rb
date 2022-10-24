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
          newline_locations = [0]
          File.readlines(File.join(@current_run_logs_path, log_id)).each do |line|
            newline_locations << (line.length + newline_locations[-1])
          end

          newline_locations
        end

        def update_all_scan_findings(scan_findings, start_line, start_column, end_line, end_column)
          scan_findings.each do |scan_finding|
            scan_finding[:start_line] = start_line
            scan_finding[:start_column] = start_column
            scan_finding[:end_line] = end_line
            scan_finding[:end_column] = end_column
            scan_finding.delete(:column)
            scan_finding.delete(:line)
          end
        end

        def remove_erroneous_column_data(finding)
          final_scan_findings = []
          finding[:scan_findings].group_by { |scan_f| scan_f[:start_line] }.each_value do |line_sfs|
            if line_sfs.one?
              final_scan_findings.push(line_sfs.first)
            else
              line_sfs.each do |sf|
                sf.delete(:start_column)
                sf.delete(:end_column)
                sf.delete(:size)
                final_scan_findings.push(sf)
              end
            end
          end
          finding[:scan_findings] = final_scan_findings.uniq
        end

        def sum_up_lines(newline_locations, from, to)
          from = 0 if from.negative?
          from = newline_locations.length - 1 if from >= newline_locations.length
          to = 0 if to.negative?
          to = newline_locations.length - 1 if to >= newline_locations.length
          newline_locations[to] - newline_locations[from]
        end

        def get_real_line_size(newline_locations, line_number)
          sum_up_lines(newline_locations, line_number - 1, line_number)
        end

        def compute_endings(finding)
          newline_locations = get_log_newline_locations(finding[:log_id])

          unique_scan_findings = finding[:scan_findings].group_by do |scan_f|
            LineColumn.new(scan_f[:start_line], scan_f[:start_column])
          end

          line_columns = unique_scan_findings.keys.sort_by { |e| [e.start_line, e.start_column] }

          lines_to_add = 0
          current_sf_start_line = -1
          current_start_line = -1

          line_columns.each do |line_column|
            sf = unique_scan_findings[line_column].first
            sf_size = sf[:size]
            sf_start_line = sf[:start_line]
            sf_start_column = sf[:start_column]

            start_line = sf_start_line + lines_to_add
            if current_sf_start_line == sf_start_line
              sf_start_column -= sum_up_lines(
                newline_locations,
                current_start_line - 1,
                start_line - 1
              )
            else
              current_sf_start_line = sf_start_line
              current_start_line = start_line
            end

            current_line_size = get_real_line_size(newline_locations, start_line)
            size_available_on_lines_parsed = current_line_size - (sf_start_column - 1)

            newlines_found = 0
            while size_available_on_lines_parsed < sf_size
              newlines_found += 1
              current_line_size = get_real_line_size(newline_locations, start_line + newlines_found)
              size_available_on_lines_parsed += current_line_size
            end

            update_all_scan_findings(
              unique_scan_findings[line_column],
              start_line,
              sf_start_column,
              start_line + newlines_found,
              current_line_size - (size_available_on_lines_parsed - sf_size) + 1
            )

            newlines_found += 1 if newlines_found.positive? && size_available_on_lines_parsed == sf_size
            lines_to_add += newlines_found
          end

          remove_erroneous_column_data(finding)

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

          result['Secrets'].each do |secret|
            matching_lines = secret.dig('Code', 'Lines').select { |num| num['IsCause'] }
            if matching_lines.one?
              match_data = matching_lines.dig(0, 'Content').to_enum(:scan, /\*+/).map do
                [Regexp.last_match.begin(0) + 1, Regexp.last_match.to_s.length]
              end

              match_data.each do |match|
                finding[:scan_findings] << {
                  name: secret['Title'],
                  start_column: match.first,
                  start_line: secret['StartLine'],
                  size: match.last
                }
              end
            # This makes sense only if Trivy starts to output private keys as multi-line matches
            else
              size = 0

              matching_lines.each do |matching_line|
                line_content = matching_line['Content']
                match_data = line_content.to_enum(:scan, /\*+/).map do
                  [Regexp.last_match.begin(0) + 1, Regexp.last_match.to_s.length]
                end
                if matching_line['FirstCause']
                  match_data.each do |match|
                    size += match.last if match.first + match.last == line_content.length + 1
                  end
                elsif matching_line['LastCause']
                  match_data.each do |match|
                    size += match.last if match.first == 1
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

          finding[:scan_findings].uniq!

          compute_endings(finding)
        end
      end
    end
  end
end
