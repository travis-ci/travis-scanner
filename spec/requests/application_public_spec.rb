require 'rails_helper'

describe 'ApplicationPublic', type: :request do
  describe 'GET /anything' do
    it 'returns a not_found response' do
      get '/anything'

      expect(response).to have_http_status(:bad_request)
    end
  end
end
