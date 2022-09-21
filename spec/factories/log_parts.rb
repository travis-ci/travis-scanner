FactoryBot.define do
  factory :log_part do
    log { association :log }
    number { Faker::Number.number(digits: 1) }
    content { 'Some content' }
    final { false }
  end
end
