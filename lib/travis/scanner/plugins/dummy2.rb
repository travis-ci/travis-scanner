require 'open3'
require 'json'

# temporary for testing purposes
module Travis
  module Scanner
    module Plugins
      class Dummy2 < Dummy1
        def initialize(plugin_scanner_cmd, plugin_config)
          super(plugin_scanner_cmd, plugin_config)
          @scan_plugin_name = 'Dummy2'
        end
      end
    end
  end
end
