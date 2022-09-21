Rails.application.configure do
  config.lograge.custom_payload do |controller|
    {
      params: controller.request.send(:parameter_filter).filter(controller.request.request_parameters),
      path_params: controller.request.path_parameters,
      user_id: controller.current_user&.id
    }
  end
end
