FactoryBot.define do
  factory :log do
    job_id { Faker::Number.number }
    content { "Starting...\nUsing AWS key: secret_aws_key" }
  end
end
