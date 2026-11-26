require "rails_helper"

RSpec.describe Metrics::Summary do
  let(:account) { create(:account) }

  def summary(**filter)
    described_class.new(Metrics::Filter.new(account:, **filter)).call
  end

  context "with wins, losses and a break-even trade" do
    before do
      deposit(account, "2026-03-01 08:00", 1000)
      [ 100, -50, -30, 0, -20, -10, 60 ].each_with_index { |net, day| closed(account, "2026-03-#{day + 2} 12:00", net) }
    end

    it "computes the figures" do
      expect(summary).to have_attributes(
        trades: 7, wins: 2, losses: 4, break_even: 1, net_profit: 50,
        gross_profit: 160, gross_loss: -110, largest_win: 100, largest_loss: -50,
        average_win: 80, average_loss: BigDecimal("-27.5"), return_rate: BigDecimal("0.05")
      )
      expect(summary.win_rate).to be_within(0.0001).of(2.0 / 7)
      expect(summary.mt5_win_rate).to be_within(0.0001).of(3.0 / 7)
      expect(summary.profit_factor).to be_within(0.0001).of(160.0 / 110)
      expect(summary.expectancy).to be_within(0.0001).of(50.0 / 7)
    end

    it "ends a losing streak at a break-even trade" do
      expect(summary.longest_losing_streak).to eq(2)
    end

    it "measures a later range against the balance it started with" do
      later = summary(from: Date.new(2026, 3, 8))

      # Balance on 8 March: 1000 + 100 - 50 - 30 + 0 - 20 - 10 = 990.
      expect(later).to have_attributes(trades: 1, net_profit: 60)
      expect(later.return_rate).to be_within(0.000001).of(60.0 / 990)
    end

    it "adds deposits made during the range to its capital, and ignores withdrawals" do
      deposit(account, "2026-03-05 08:00", 500)
      deposit(account, "2026-03-06 08:00", -200)

      expect(summary.return_rate).to be_within(0.000001).of(50.0 / 1500)
    end

    it "measures one symbol against the whole account's capital" do
      closed(account, "2026-03-20 12:00", 40, symbol: "US30")

      expect(summary(symbol: "US30").return_rate).to eq(BigDecimal("0.04"))
    end
  end

  it "counts commission and swap against a trade" do
    create(:trade, account:, profit: 2, commission: -7, swap: 0)

    expect(summary).to have_attributes(wins: 0, losses: 1, net_profit: -5)
  end

  it "leaves ratios undefined without trades" do
    expect(summary).to have_attributes(
      trades: 0, net_profit: 0, win_rate: nil, mt5_win_rate: nil, profit_factor: nil, expectancy: nil,
      average_win: nil, average_loss: nil, largest_win: nil, largest_loss: nil,
      return_rate: nil, longest_losing_streak: 0
    )
  end

  it "has no profit factor without losses" do
    closed(account, "2026-03-02 12:00", 10)

    expect(summary).to have_attributes(profit_factor: nil, average_loss: nil, longest_losing_streak: 0)
  end
end
