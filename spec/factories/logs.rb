FactoryBot.define do
  factory :log do
    job_id { Faker::Number.number(digits: 4) }
    content { "Starting...\nUsing AWS key: secret_aws_key" }
  end
end
