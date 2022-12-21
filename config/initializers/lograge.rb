if ENV["RAILS_LOG_LOGRAGE_ENABLED"].present?
  Rails.application.configure do
    config.lograge.base_controller_class = 'ActionController::API'
    config.lograge.custom_payload do |controller|
      fullpath = controller.request.fullpath rescue nil
      content_type = controller.request.content_type rescue nil
      request_parameters = controller.request.send(:parameter_filter).filter(controller.request.request_parameters) rescue nil
      query_parameters = controller.request.send(:parameter_filter).filter(controller.request.query_parameters) rescue nil
      path_parameters = controller.request.path_parameters rescue nil

      {
        fullpath: fullpath,
        content_type: content_type,
        request_parameters: request_parameters,
        query_parameters: query_parameters,
        path_parameters: path_parameters,
        user_id: controller.current_user&.id
      }
    end
  end
end
