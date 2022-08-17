# frozen_string_literal: true

FactoryBot.define do
  factory :log do
    job_id { 1 }
    content { 'Hello World!' }
  end
end
