FactoryBot.define do
  factory :account do
    name { "Sample account" }
    broker { "Example Broker" }
    server { "ExampleBroker-Demo" }
    sequence(:login) { |n| (1_000_000 + n).to_s }
    currency { "USD" }
  end

  factory :account_import do
    after(:build) do |import|
      import.report.attach(io: StringIO.new("test"), filename: "report.xlsx") unless import.report.attached?
    end
  end

  factory :robot do
    account
    sequence(:key) { |n| "robot-#{n}" }
    name { key }
  end

  factory :trade do
    account
    sequence(:position_id) { |n| 5_000_000 + n }
    symbol { "EURUSD" }
    side { "buy" }
    volume { 0.1 }
    opened_at { Time.utc(2026, 1, 5, 10) }
    closed_at { opened_at + 1.hour }
    open_price { 1.1 }
    close_price { 1.101 }
    profit { 10 }
    commission { -0.7 }
    swap { -0.2 }
  end
end
