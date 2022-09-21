module Travis
  module Scanner
    class Runner
      def run(logs_path)
        scanner_plugins.each do |scanner_plugin|
          scanner_plugin.start(logs_path)
        end

        process_results(@scanner_plugins.map(&:result))
      end

      private

      def scanner_plugins
        enabled_plugins = Settings.plugins.filter { |_key, value| value.enabled != false }
        @scanner_plugins ||= enabled_plugins.map do |key, value|
          "Travis::Scanner::Plugins::#{key.to_s.camelize}".constantize.new(value['cmdline'], value)
        end
      end

      def process_results(results)
        logs = {}
        results.each do |scanner_result|
          scanner_result[:scan_results].each do |result|
            log_id = result[:log_id]
            logs[log_id] ||= {}
            result[:scan_findings].each do |scan_finding|
              new_finding = {
                plugin_name: scanner_result[:scanner_name],
                finding_name: scan_finding[:name]
              }
              new_finding[:start_column] = scan_finding[:start_column] if scan_finding.key?(:start_column)
              new_finding[:end_column] = scan_finding[:end_column] if scan_finding.key?(:end_column)
              new_finding[:end_line] = scan_finding[:end_line] if scan_finding.key?(:end_line)
              (logs[log_id][scan_finding[:start_line]] ||= []).push(new_finding)
            end
          end
        end

        logs
      end
    end
  end
end
