FactoryBot.define do
  factory :scan_result do
    job { association :job }
    log { association :log }
    repository { association :repository }
    owner_id { Faker::Number.number(digits: 4) }
    owner_type { 'User' }
    content do
      {
        '1': [
          {
            size: 20,
            column: 9,
            plugin_name: 'trivy',
            finding_name: 'AWS Access Key ID'
          },
          {
            size: -1,
            column: -1,
            plugin_name: 'detect_secrets',
            finding_name: 'AWS Access Key'
          }
        ]
      }
    end
    issues_found { 1 }
    token { '123' }
  end
end
