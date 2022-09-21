FactoryBot.define do
  factory :log do
    job { association :job }
    content { "Starting...\nUsing AWS key: secret_aws_key" }
  end
end
