FactoryBot.define do
  factory :repository do
    owner_id { Faker::Number.number(digits: 4) }
    owner_type { 'User' }
  end
end
