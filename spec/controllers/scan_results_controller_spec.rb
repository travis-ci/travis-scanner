require 'rails_helper'

describe ScanResultsController, type: :controller do
  let(:repo) { create :repository }
  let(:job) { create :job, repository_id: repo.id }
  let(:log) do
    create :log, job_id: job.id, scan_status: Log.scan_statuses[:queued], content: "content AKIAIOSFODNN7EXAMPLE\nTest"
  end
  let!(:scan_result) { create :scan_result, repository_id: repo.id, log_id: log.id, job_id: job.id, issues_found: 1 }
  let(:formatted_scan_result) do
    {
      archived: nil,
      build_id: nil,
      build_number: job.number.split('.')[0],
      commit_branch: nil,
      commit_compare_url: nil,
      commit_sha: 'SHA',
      content: {
        '1': [
          {
            column: 9,
            finding_name: 'AWS Access Key ID',
            plugin_name: 'trivy',
            size: 20
          },
          {
            column: -1,
            finding_name: 'AWS Access Key',
            plugin_name: 'detect_secrets',
            size: -1
          }
        ]
      },
      created_at: scan_result.created_at.strftime('%Y-%m-%dT%H:%M:%S.%3NZ'),
      formatted_content: "travis_fold:start:trivy\r\e[0K\e[33;1mIn line 1 of your build job log trivy found" \
                         "\e[0m\nAWS Access Key ID\ntravis_fold:end:trivy\n\n\ntravis_fold:start:detect_secrets" \
                         "\r\e[0K\e[33;1mIn line 1 of your build job log detect_secrets found\e[0m\nAWS Access Key" \
                         "\ntravis_fold:end:detect_secrets\n\n\n\n\nOur backend build job log monitoring uses:" \
                         "\n • trivy\n • detect_secrets\nCalled via command line and under respective " \
                         'permissive licenses.',
      id: scan_result.id,
      issues_found: scan_result.issues_found,
      job_finished_at: nil,
      job_id: scan_result.job_id,
      job_number: job.number.split('.')[1],
      log_id: scan_result.log_id,
      owner_id: scan_result.owner_id,
      owner_type: scan_result.owner_type,
      purged_at: nil,
      repository_id: scan_result.repository_id,
      token: scan_result.token,
      token_created_at: nil
    }
  end

  before do
    request.headers['Authorization'] = "Token token=#{Settings.scanner_auth_token}"
  end

  describe 'GET index' do
    it 'displays scan results' do
      get :index, params: { repository_id: repo.id, page: 1, limit: 25 }, format: :json

      expect(response).to be_successful
      pp body
      expect(body).to eq({
                           scan_results: [formatted_scan_result],
                           total_count: 1
                         })
    end
  end

  describe 'GET show' do
    it 'displays scan result' do
      get :show, params: { id: scan_result.id }, format: :json

      expect(response).to be_successful
      expect(body).to eq(scan_result: formatted_scan_result)
    end
  end
end
