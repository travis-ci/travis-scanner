FactoryBot.define do
  factory :log do
    job_id { Faker::Number }
    content { "Starting...\nUsing AWS key: secret_aws_key" }
  end
end
