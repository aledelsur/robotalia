require "rails_helper"

RSpec.describe Metrics::Filter do
  let(:account) { create(:account) }

  it "includes both end dates in full" do
    inside = [ closed(account, "2026-03-01 00:00:00", 1), closed(account, "2026-03-31 23:59:59", 1) ]
    closed(account, "2026-02-28 23:59:59", 1)
    closed(account, "2026-04-01 00:00:00", 1)

    filter = described_class.from_params(account, { from: "2026-03-01", to: "2026-03-31" })

    expect(filter.trades).to match_array(inside)
  end

  it "filters by symbol and robot" do
    robot = create(:robot, account:)
    wanted = closed(account, "2026-03-02 10:00", 1, symbol: "US30", robot:)
    closed(account, "2026-03-02 10:00", 1, symbol: "US30")
    closed(account, "2026-03-02 10:00", 1, symbol: "EURUSD", robot:)

    filter = described_class.from_params(account, { symbol: "US30", robot_id: robot.id.to_s })

    expect(filter.trades).to eq([ wanted ])
    expect(filter.to_params).to eq(symbol: "US30", robot_id: robot.id)
  end

  it "never reaches another account's trades" do
    other = create(:trade, robot: create(:robot))

    expect(described_class.from_params(account, { robot_id: other.robot_id.to_s }).trades).to be_empty
  end

  it "ignores values that do not parse" do
    filter = described_class.from_params(account, { from: "yesterday", to: "999999-01-01", symbol: "", robot_id: "1 OR 1" })

    expect(filter).to eq(described_class.new(account:))
    expect(filter).not_to be_active
  end

  it "survives values of the wrong shape" do
    filter = described_class.from_params(account, { from: [ "x" ], robot_id: "9" * 40 })

    expect(filter.trades).to be_empty
  end
end
