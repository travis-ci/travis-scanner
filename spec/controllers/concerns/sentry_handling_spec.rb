require 'rails_helper'

describe SentryHandling, type: :controller do
  controller(ApplicationController) do
    include SentryHandling

    def fake_action; redirect_to '/an_url'; end
  end

  before do
    routes.draw {
      get 'fake_action' => 'anonymous#fake_action'
    }
  end
    
  describe 'sentry_handling' do
    before do
      allow(Sentry).to receive(:set_extras)
      allow(Sentry).to receive(:set_context)

      get :fake_action
    end

    it 'initializes sentry' do
      expect(response).to redirect_to('/an_url')
      expect(Sentry).to have_received(:set_extras)
      expect(Sentry).to have_received(:set_context)
    end
  end
end
