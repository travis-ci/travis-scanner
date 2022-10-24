require_relative 'runner'
require_relative 'plugins/base'
require_relative 'plugins/trivy'
require_relative 'plugins/detect_secrets'
require_relative '../../../app/services/application_service'
require_relative '../../../app/services/base_logs_service'
require_relative '../../../app/services/process_logs_service'
require_relative '../../../app/services/censor_logs_service'
require 'active_support/core_ext/hash/indifferent_access'
require 'config'
require 'rails'
require 'json'

Config.load_and_set_settings('../../../config/settings.yml')

build_job_logs_dir = '../../../logs'

log_ids = %w[1 2 3 4]
ProcessLogsService.call log_ids
# plugins_result = Travis::Scanner::Runner.new.run(build_job_logs_dir)

# puts JSON.pretty_generate(plugins_result)

# file_path = '../../../logs/1.log'
# newline_locations = [0]
# File.readlines(file_path).each do |line|
#     newline_locations << line.length + newline_locations[-1]
# end
# newline_locations.drop(1)

# puts newline_locations
