require "rails_helper"

RSpec.describe Metrics::MonthlyReturns do
  let(:account) { create(:account) }

  def months(**filter)
    described_class.new(Metrics::Filter.new(account:, **filter)).call
  end

  before do
    deposit(account, "2026-01-01 08:00", 1000)
    closed(account, "2026-01-15 12:00", 100)
    deposit(account, "2026-02-01 08:00", 900)
    deposit(account, "2026-02-20 08:00", -500)
    closed(account, "2026-02-27 23:00", -200)
    closed(account, "2026-03-01 00:00", 30)
    closed(account, "2026-03-02 12:00", 100, symbol: "US30")
  end

  it "measures each month against its opening balance and deposits" do
    expect(months.map { [ _1.month, _1.trades, _1.net_profit ] }).to eq([
      [ Date.new(2026, 1, 1), 1, 100 ], [ Date.new(2026, 2, 1), 1, -200 ], [ Date.new(2026, 3, 1), 2, 130 ]
    ])
    # March opens with 1000 + 100 + 900 - 500 - 200 = 1300.
    expect(months.map { _1.return_rate.to_f }).to eq([ 0.1, -0.1, 0.1 ])
  end

  it "carries the whole account's balance through a symbol filter" do
    expect(months(symbol: "US30").map { [ _1.month.month, _1.return_rate.round(6) ] })
      .to eq([ [ 3, (BigDecimal("100") / 1300).round(6) ] ])
  end

  it "counts only the days of a month inside the range" do
    result = months(from: Date.new(2026, 3, 2))

    expect(result.map(&:net_profit)).to eq([ 100 ])
    expect(result.first.return_rate.round(6)).to eq((BigDecimal("100") / 1330).round(6))
  end

  it "skips months without trades but keeps their cash flows" do
    deposit(account, "2026-04-10 08:00", 570)
    closed(account, "2026-05-05 12:00", 200)

    expect(months.map { _1.month.month }).to eq([ 1, 2, 3, 5 ])
    # 1300 + 130 + 570 = 2000.
    expect(months.last.return_rate).to eq(BigDecimal("0.1"))
  end
end
