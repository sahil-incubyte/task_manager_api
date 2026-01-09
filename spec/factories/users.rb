FactoryBot.define do
  factory :user do
    name { "Test User" }
    sequence(:email) { |n| "user#{n}@test.com" }
    password_digest { "password" }
  end
end
