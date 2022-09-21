module RequestsSpecHelper
  def json_headers
    {
      content_type: :json,
      accept: :json
    }
  end

  def token_headers
    json_headers.merge(authorization: try(:token).to_s)
  end

  def bearer_token_headers
    json_headers.merge(authorization: "Bearer #{try(:token)}".strip)
  end

  def body
    JSON.parse(response.body, symbolize_names: true) rescue {}
  end

  def body_errors
    body[:errors]
  end
end

RSpec.configure do |config|
  config.include RequestsSpecHelper
end
