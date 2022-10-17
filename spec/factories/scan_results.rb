FactoryBot.define do
  factory :scan_result do
    job { association :job }
    log { association :log }
    owner_id { Faker::Number.number(digits: 4) }
    owner_type { 'User' }
    content { '{}' }
    issues_found { 0 }
    token { '123' }
  end
end
