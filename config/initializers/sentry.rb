require 'active_support/parameter_filter'

Sentry.init do |config|
  config.dsn = Settings.sentry_dsn if Settings.sentry_dsn.present?

  config.async = lambda do |event, hint|
    Sentry::SendEventJob.perform_later(event, hint)
  end

  filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
  config.before_send = lambda do |event, _hint|
    # use Rails' parameter filter to sanitize the event
    filter.filter(event.to_hash)
  end

  config.breadcrumbs_logger = [:sentry_logger, :active_support_logger]
  config.breadcrumbs_logger << :http_logger if Settings.sentry_dsn.present?

  config.logger = Sentry::Logger.new($stdout)
end
