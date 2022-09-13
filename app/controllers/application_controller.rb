class ApplicationController < ActionController::API
  include SentryHandling

  before_action :set_sentry_context
end
