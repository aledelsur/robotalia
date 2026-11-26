FactoryBot.define do
  factory :user do
    email_address { "owner@example.com" }
    password { "correct-horse-battery" }

    trait :demo do
      email_address { "demo@example.com" }
      demo { true }
    end
  end
end
