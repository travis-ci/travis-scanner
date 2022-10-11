require 'rails_helper'

RSpec.describe ProcessLogsJob, type: :job do
  describe '#perform_now' do
    let(:log_ids) { [1, 2, 3] }

    it 'calls the processing logs service' do
      expect(ProcessLogsService).to receive(:call).with(log_ids)
      described_class.perform_now(log_ids)
    end
  end
end
