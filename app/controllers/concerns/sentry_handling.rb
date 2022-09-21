module SentryHandling
  extend ActiveSupport::Concern

  private

  def set_sentry_context
    return unless sentry_logging_enabled?

    # Sentry.set_user(id: current_user&.id)
    Sentry.set_extras(url: request.url)
    Sentry.set_context(:params, params.to_unsafe_h)
  end

  def sentry_logging_enabled?
    Settings.sentry_dsn.present?
  end
end
