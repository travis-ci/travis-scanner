# Unbuffer stdout to ensure application output is immediately visible.
$stdout.sync = true

# Load the Rails application.
require_relative "application"

# Initialize the Rails application.
Rails.application.initialize!
