require 'open3'
require 'json'

module Travis
  module Scanner
    module Plugins
      class Dummy1 < Base
        def initialize(plugin_scanner_cmd, plugin_config)
          super(plugin_scanner_cmd, plugin_config)

          @log_findings = {}
          @scan_plugin_name = 'Dummy1'
        end

        protected
        def compute_command_line(logs_path)
          "#{@plugin_scanner_cmd} --scan_path #{logs_path}"
        end

        def parse_line(line)
          m = /Finding: (?<finding>.+) File: (?<log>.+) Line: (?<line>.+) Column: (?<column>.+) Size: (?<size>.+)/.match(line)
          (@log_findings[m[:log]] ||= []).push({ name: m[:finding], line: m[:line], column: m[:column], size: m[:size] })
        end

        def get_scan_results
          @log_findings.map { |key, value| { log_id: key, scan_findings: value } }
        end
      end
    end
  end
end
