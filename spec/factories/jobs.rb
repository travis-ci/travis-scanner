FactoryBot.define do
  factory :job do
    repository { association :repository }
    owner_id { Faker::Number.number(digits: 4) }
    owner_type { 'User' }
  end
end
