require 'open3'

module Travis
  module Scanner
    module Plugins
      class Base
        def initialize(plugin_scanner_cmd, plugin_config)
          @plugin_scanner_cmd = plugin_scanner_cmd
          @plugin_config = plugin_config

          @scan_plugin_name = 'NOT IMPLEMENTED'
        end

        def start(logs_path)
          @waiter_thread = Thread.new do
            Timeout.timeout(Settings.plugin_execution_timeout) do
              execute_plugin(logs_path)
            end
          end
        end

        def result
          begin
            @waiter_thread.join
          rescue => e
            raise "An error happened during #{@scan_plugin_name} execution: #{e.message}\n#{e.backtrace.join("\n")}"
          end

          @plugin_stderr.each_line { |line| Rails.logger.info("[#{@scan_plugin_name}] STDERR: #{line}") }
          @plugin_stdout.each_line { |line| parse_line(line) }

          {
            scanner_name: @scan_plugin_name,
            scan_start_time: @scan_start_time,
            scan_end_time: @scan_end_time,
            scan_results: scan_results
          }
        end

        private

        def execute_plugin(logs_path)
          @scan_start_time = Time.zone.now
          @plugin_stdin, @plugin_stdout, @plugin_stderr, @waiter_th = Open3.popen3(compute_command_line(logs_path))

          begin
            Process.waitpid(@waiter_th.pid)
          rescue Errno::ECHILD
            # in case process exits very quickly
          end

          @scan_end_time = Time.zone.now
        end

        protected

        def compute_command_line(logs_path)
          raise NotImplementedError
        end

        def parse_line(line)
          raise NotImplementedError
        end

        def scan_results
          raise NotImplementedError
        end
      end
    end
  end
end
