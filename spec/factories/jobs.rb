FactoryBot.define do
  factory :job do
    repository { association :repository }
    commit { association :commit }
    owner_id { Faker::Number.number(digits: 4) }
    owner_type { 'User' }
    number { '1.1' }
  end
end
