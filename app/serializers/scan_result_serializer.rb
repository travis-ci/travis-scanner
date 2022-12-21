class ScanResultSerializer < ActiveModel::Serializer
  attributes :id, :repository_id, :job_id, :log_id, :owner_id, :owner_type, :content, :issues_found,
             :archived, :purged_at, :created_at,
             :build_id, :build_number, :job_number, :job_finished_at,
             :commit_sha, :commit_compare_url, :commit_branch, :formatted_content

  def build_id
    object.job.source_id
  end

  def build_number
    object.job.number.split('.')[0]
  end

  def job_number
    object.job.number.split('.')[1]
  end

  def job_finished_at
    object.job.finished_at
  end

  def commit_sha
    object.job.commit.commit
  end

  def commit_compare_url
    object.job.commit.compare_url
  end

  def commit_branch
    object.job.commit.branch
  end

  def formatted_content
    result = formatted_findings

    result << "\n\nOur backend build job log monitoring uses:\n"
    Settings.plugins.each { |k, v| result << " • #{k}\n" if v.enabled }
    result << 'Called via command line and under respective permissive licenses.'
  end

  private

  def formatted_findings
    result = ''
    object.content.each do |line, findings|
      findings.group_by { |a| a['plugin_name'] }.each do |plugin_name, plugin_findings|
        result << ("travis_fold:start:#{plugin_name}\r\u001b[0K\u001b[33;1mIn line " \
          "#{line} of your build job log #{plugin_name} found\u001b[0m\n")
        plugin_findings.each { |finding| result << "#{finding['finding_name']}\n" }
        result << "travis_fold:end:#{plugin_name}\n\n\n"
      end
    end

    result
  end
end
