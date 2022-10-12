FactoryBot.define do
  factory :log do
    job { association :job }
    content { "Starting...\nUsing AWS key: secret_aws_key" }
  end

  factory :log_part do
    log { association :log }
    content { 'Some content' }
    number { Faker::Number.number(digits: 1) }
    final { false }
  end

  factory :job do
    repository { association :repository }
    owner_id { Faker::Number.number(digits: 4) }
    owner_type { 'User' }
  end

  factory :repository do
    owner_id { Faker::Number.number(digits: 4) }
    owner_type { 'User' }
  end

  factory :scan_result do
    log { association :log }
    job { association :job }
    owner_id { Faker::Number.number(digits: 4) }
    owner_type { 'User' }
    content { '{}' }
    issues_found { 0 }
    token { '123' }
  end
end
