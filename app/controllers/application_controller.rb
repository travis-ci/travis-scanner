class ApplicationController < ActionController::API
  include ExceptionHandling
  include SentryHandling

  before_action :set_sentry_context
end
