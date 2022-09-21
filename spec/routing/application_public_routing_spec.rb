require 'rails_helper'

describe ApplicationPublicController, type: :routing do
  describe 'routing' do
    it 'routes to #routing_error' do
      expect(get: '/anything').to route_to('application_public#routing_error', anything: 'anything')
    end
  end
end
