require 'rails_helper'

RSpec.describe ProcessLogsJob, type: :job do
  describe '#perform_now' do
    let(:log_ids) { [1, 2, 3] }

    before { allow(ProcessLogsService).to receive(:call).and_call_original }

    it 'calls the processing logs service' do
      described_class.perform_now(log_ids)

      expect(ProcessLogsService).to have_received(:call).with(log_ids)
    end
  end
end
