require 'rails_helper'

RSpec.describe Travis::Scanner::Plugins::Base do
  subject(:base_plugin) { described_class.new(nil, nil) }

  describe '#result' do
    context 'when there an error' do
      let(:thread) { double }

      before do
        allow(Thread).to receive(:new).and_return(thread)
        allow(thread).to receive(:join).and_raise(StandardError)
      end

      it 'raises an error' do
        base_plugin.start('')

        expect { base_plugin.result }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#compute_command_line' do
    it 'raises an error' do
      expect { base_plugin.send(:compute_command_line, '') }.to raise_error(NotImplementedError)
    end
  end

  describe '#parse_line' do
    it 'raises an error' do
      expect { base_plugin.send(:parse_line, '') }.to raise_error(NotImplementedError)
    end
  end

  describe '#scan_results' do
    it 'raises an error' do
      expect { base_plugin.send(:scan_results) }.to raise_error(NotImplementedError)
    end
  end
end
