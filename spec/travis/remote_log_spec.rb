require 'rails_helper'

RSpec.describe Travis::RemoteLog, type: :library do
  subject(:library) { described_class.new(:job_id, :archived_at, :archive_verified) }

  let(:job_id) { job_id }
  let(:archived_at) { archived_at }
  let(:archive_verified) { archive_verified }

  describe '#archived_log_content' do
    context 'when fetch content from s3' do
      let!(:job_id) { 1 }
      let!(:archived_at) { Time.now }
      let!(:archive_verified) { true }

      it 'makes a call to s3 bucket' do
        client = double()
        response = double()
        body = double()

        allow(body).to receive(:string).and_return('content')
        allow(response).to receive(:body).and_return(body)
        allow(Aws::S3::Client).to receive(:new).and_return(client)
        allow(client).to receive(:get_object).and_return(response)
        allow(ENV).to receive(:[]).with("ENVIRONMENT").and_return('staging')
        allow(ENV).to receive(:[]).with("HOST").and_return('travis-ci.org')

        library.archived_log_content
        expect(client).to have_received(:get_object)
      end
    end
  end
end