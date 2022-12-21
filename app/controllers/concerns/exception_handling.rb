module ExceptionHandling
  extend ActiveSupport::Concern

  included do
    rescue_from Exception, with: :render_bad_request
    rescue_from Authentication::Unauthorized, with: :render_unauthorized
    rescue_from Authentication::Forbidden, with: :render_forbidden
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotDestroyed,
                with: :render_unprocessable_entity

    def routing_error
      render_errors('Invalid URL or method.', :bad_request)
    end

    private

    def render_bad_request(error)
      log_error(error)
      render_errors(error.message, :bad_request)
    end

    def render_unauthorized(error)
      render_errors(error.message, :unauthorized)
    end

    def render_forbidden(error)
      render_errors(error.message, :forbidden)
    end

    def render_not_found(_error)
      render_errors("Couldn't find the entity!", :not_found)
    end

    def render_unprocessable_entity(exception)
      render_errors(exception.record&.errors)
    end

    def render_errors(errors, status = :unprocessable_entity)
      errors ||= {}
      render json: { errors: errors }, status: status
    end

    def log_error(error)
      Rails.logger.error(error)
      Sentry.capture_exception(error) if Settings.sentry.dsn.present?
    end
  end
end
