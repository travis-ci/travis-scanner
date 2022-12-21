require 'rails_helper'

RSpec.describe LogPart do
  let(:log_part) { create :log_part }

  it 'belongs to a log' do
    expect(log_part.log).to be_a(Log)
  end
end
