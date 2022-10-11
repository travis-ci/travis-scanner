require 'rails_helper'

RSpec.describe EnqueueProcessingLogsJob, type: :job do
  describe '#perform_now' do
    before { allow(EnqueueProcessingLogsService).to receive(:call).and_call_original }

    it 'calls the enqueue processing logs service' do
      described_class.perform_now

      expect(EnqueueProcessingLogsService).to have_received(:call)
    end
  end
end
