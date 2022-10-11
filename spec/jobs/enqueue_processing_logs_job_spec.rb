require 'rails_helper'

RSpec.describe EnqueueProcessingLogsJob, type: :job do
  describe '#perform_now' do
    it 'calls the enqueue processing logs service' do
      expect(EnqueueProcessingLogsService).to receive(:call)
      described_class.perform_now
    end
  end
end
