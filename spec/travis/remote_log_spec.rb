require 'rails_helper'

RSpec.describe Travis::RemoteLog do
  subject(:remote_log) { described_class.new(:job_id, :archived_at, :archive_verified) }

  let(:job_id) { Faker::Number.number(digits: 4) }
  let(:archived_at) { Time.now.utc }
  let(:archive_verified) { true }

  describe '#archived_log_content' do
    let(:client) { double }
    let(:response) { double }
    let(:body) { double }

    before do
      allow(body).to receive(:string).and_return('content')
      allow(response).to receive(:body) { body }
      allow(Aws::S3::Client).to receive(:new) { client }
      allow(Rails.env).to receive(:staging?).and_return('staging')
      allow(ENV).to receive(:[]).with('HOST').and_return('travis-ci.org')
      allow(client).to receive(:get_object) { response }
    end

    context 'when fetch content from s3' do
      it 'makes a call to s3 bucket' do
        expect(remote_log.archived_log_content).to eq('content')
        expect(client).to have_received(:get_object)
      end
    end

    context 'when there is an error' do
      before { allow(client).to receive(:get_object).and_raise(Aws::S3::Errors::NoSuchKey.new(nil, nil)) }

      it 'makes a call to s3 bucket' do
        expect(remote_log.archived_log_content).to eq('')
        expect(client).to have_received(:get_object)
      end
    end
  end

  describe '#update_content' do
    context 'updates content in s3' do
      let(:client) { double }

      before do
        allow(Aws::S3::Client).to receive(:new) { client }
        allow(Rails.env).to receive(:staging?).and_return('staging')
        allow(ENV).to receive(:[]).with('HOST').and_return('travis-ci.org')
        allow(client).to receive(:put_object)
      end

      it 'makes a call to s3 bucket' do
        remote_log.update_content('content')

        expect(client).to have_received(:put_object)
      end
    end
  end

  describe '#store_scan_report' do
    context 'updates content in s3' do
      let(:client) { double }

      before do
        allow(Aws::S3::Client).to receive(:new) { client }
        allow(Rails.env).to receive(:staging?).and_return('staging')
        allow(ENV).to receive(:[]).with('HOST').and_return('travis-ci.org')
        allow(client).to receive(:put_object)
      end

      it 'makes a call to s3 bucket' do
        remote_log.store_scan_report(1, '', {})

        expect(client).to have_received(:put_object).twice
      end
    end
  end
end
