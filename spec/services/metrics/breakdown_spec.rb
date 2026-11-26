require "rails_helper"

RSpec.describe Metrics::Breakdown do
  let(:account) { create(:account) }
  let(:robot) { create(:robot, account:, name: "Model 3 · EURUSD") }
  let(:filter) { Metrics::Filter.new(account:) }

  before do
    closed(account, "2026-03-02 12:00", 100, robot:, side: "buy", symbol: "EURUSD")
    closed(account, "2026-03-03 12:00", -40, robot:, side: "sell", symbol: "EURUSD")
    closed(account, "2026-03-04 12:00", -20, robot:, side: "sell", symbol: "US30")
    closed(account, "2026-03-05 12:00", 5, symbol: "US30")
  end

  it "splits by symbol, most profitable first" do
    rows = described_class.new(filter, by: :symbol).call

    expect(rows.map { [ _1.name, _1.tally.trades, _1.tally.net_profit, _1.tally.win_rate ] })
      .to eq([ [ "EURUSD", 2, 60, 0.5 ], [ "US30", 2, -15, 0.5 ] ])
    expect(rows.first.tally.profit_factor).to eq(BigDecimal("2.5"))
  end

  it "splits by robot, with long and short trades, and groups trades with no robot" do
    rows = described_class.new(filter, by: :robot).call

    expect(rows.map { [ _1.id, _1.name, _1.tally.net_profit ] })
      .to eq([ [ robot.id, "Model 3 · EURUSD", 40 ], [ nil, "No robot", 5 ] ])
    expect(rows.first.sides.map { [ _1.name, _1.tally.trades, _1.tally.net_profit ] })
      .to eq([ [ "Long", 1, 100 ], [ "Short", 2, -60 ] ])
  end

  it "follows the filter" do
    rows = described_class.new(filter.with(symbol: "US30"), by: :robot).call

    expect(rows.map { [ _1.name, _1.tally.trades ] }).to eq([ [ "No robot", 1 ], [ "Model 3 · EURUSD", 1 ] ])
  end

  it "rejects an unknown dimension" do
    expect { described_class.new(filter, by: :comment) }.to raise_error(ArgumentError)
  end
end
