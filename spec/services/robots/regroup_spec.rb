require "rails_helper"

RSpec.describe Robots::Regroup do
  let(:account) { create(:account) }

  def trade(comment, robot_key)
    robot = robot_key && (account.robots.find_by(key: robot_key) || create(:robot, account:, key: robot_key))
    create(:trade, account:, robot:, comment:)
  end

  it "merges the robots that differ only in direction, and removes the old ones" do
    long = trade("M3_EURUSD_Long", "m3_eurusd_long")
    short = trade("M3_EURUSD_Short", "m3_eurusd_short")
    manual = trade(nil, nil)

    described_class.new(account).call

    expect(account.robots.pluck(:key, :name)).to eq([ [ "m3_eurusd", "Model 3 · EURUSD" ] ])
    expect([ long, short ].map { _1.reload.robot&.key }).to eq(%w[m3_eurusd m3_eurusd])
    expect(manual.reload.robot).to be_nil
  end

  it "keeps the name of a robot whose key does not change, and can run again" do
    trade("M5_Long", "m5")
    account.robots.first.update!(name: "Breakout")

    2.times { described_class.new(account).call }

    expect(account.robots.pluck(:name)).to eq([ "Breakout" ])
  end

  it "leaves other accounts alone" do
    other = create(:trade, robot: create(:robot, key: "x_long"), comment: "x_Long")

    described_class.new(account).call

    expect(other.reload.robot.key).to eq("x_long")
  end
end
