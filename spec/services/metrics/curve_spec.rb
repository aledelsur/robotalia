require "rails_helper"

RSpec.describe Metrics::Curve do
  let(:account) { create(:account) }

  def curve(**filter)
    described_class.new(Metrics::Filter.new(account:, **filter)).call
  end

  before do
    deposit(account, "2026-03-01 08:00", 1000)
    closed(account, "2026-03-02 12:00", 200)    # balance 1200, the peak
    closed(account, "2026-03-03 12:00", -300)   # balance 900
  end

  it "follows balance, equity and drawdown" do
    expect(curve.points.map { [ _1.balance, _1.equity, _1.drawdown ] })
      .to eq([ [ 1000, 1000, 0 ], [ 1200, 1200, 0 ], [ 900, 900, 300 ] ])
    expect(curve).to have_attributes(max_drawdown: 300, max_drawdown_rate: 0.25)
    expect(curve.points.map(&:drawdown_rate)).to all(be_a(Float))
  end

  it "thins to one point a day without losing the day's deepest drawdown" do
    closed(account, "2026-03-03 15:00", 250)

    day = curve.daily.last

    expect(curve.daily.size).to eq(3)
    expect(day).to have_attributes(balance: 1150, drawdown: 300, drawdown_rate: 0.25)
  end

  it "does not take a deposit during a drawdown for a recovery" do
    deposit(account, "2026-03-04 08:00", 500)

    expect(curve.points.last).to have_attributes(balance: 1400, equity: 900, drawdown: 300)
    expect(curve.points.last.drawdown_rate).to be_within(0.000001).of(300.0 / 1700)
    expect(curve.max_drawdown_rate).to eq(0.25)
  end

  it "does not take a withdrawal for a drawdown" do
    deposit(account, "2026-03-02 18:00", -400)
    closed(account, "2026-03-05 12:00", 300)

    expect(curve.points.map(&:drawdown)).to eq([ 0, 0, 0, 300, 0 ])
    expect(curve.points.last).to have_attributes(balance: 800, equity: 1200)
    expect(curve.max_drawdown_rate).to be_within(0.000001).of(300.0 / 800)
  end

  it "starts a later range at the balance it had then, with no earlier drawdown" do
    closed(account, "2026-03-10 12:00", -90)

    result = curve(from: Date.new(2026, 3, 5))

    expect(result.points.map { [ _1.balance, _1.drawdown ] }).to eq([ [ 900, 0 ], [ 810, 90 ] ])
    expect(result.max_drawdown_rate).to eq(0.1)
  end

  it "counts a loss as drawdown when the range opens with it" do
    result = curve(from: Date.new(2026, 3, 3))

    expect(result).to have_attributes(max_drawdown: 300, max_drawdown_rate: 0.25)
  end

  it "is empty for an account with no history" do
    result = described_class.new(Metrics::Filter.new(account: create(:account))).call

    expect(result).to have_attributes(points: [], max_drawdown: 0, max_drawdown_rate: 0.0)
  end

  it "ends at the balance on the demo report's last deal" do
    demo = Demo::AccountGenerator.new.call

    points = described_class.new(Metrics::Filter.new(account: demo)).call.points

    expect(points.last.balance).to eq(demo.deals.order(:ticket).last.balance)
    expect(points.last.equity).to eq(10_000 + demo.trades.sum(:net_profit))
  end
end
