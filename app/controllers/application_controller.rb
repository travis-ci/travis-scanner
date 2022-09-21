class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods
  include ExceptionHandling
  include SentryHandling

  before_action :authenticate_token!
  before_action :set_sentry_context

  private

  def authenticate_token!
    authenticate_or_request_with_http_token do |token, _options|
      ActiveSupport::SecurityUtils.secure_compare(token, Settings.scanner_auth_token)
    end
  end
end
