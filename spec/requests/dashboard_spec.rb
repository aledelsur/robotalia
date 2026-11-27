require "rails_helper"

RSpec.describe "Dashboard" do
  let(:account) { create(:account) }
  let(:robot) { create(:robot, account:, name: "Model 3 · EURUSD") }

  before do
    deposit(account, "2026-01-01 08:00", 1000)
    closed(account, "2026-01-15 12:00", 100, robot:, symbol: "EURUSD")
    closed(account, "2026-02-10 12:00", -40, robot:, symbol: "EURUSD", side: "sell")
    closed(account, "2026-02-11 12:00", 15, symbol: "US30")
    sign_in
  end

  def net_profit
    response.parsed_body.at_css("[data-testid=net-profit]").text
  end

  it "shows the figures, charts, breakdowns and a lazy trades table" do
    get account_path(account)

    expect(net_profit).to eq("USD 75.00")
    expect(response.body).to include("Profit factor", "2.88", "Monthly returns", "By symbol", "Model 3 · EURUSD")
    expect(response.parsed_body.at_css("turbo-frame#trades")["src"]).to eq(account_trades_path(account))
    points = JSON.parse(response.parsed_body.at_css("[data-controller=equity-chart]")["data-equity-chart-points-value"])
    expect(points.first).to eq([ "2026-01-01", 1000.0, 1000.0, 0.0 ])
    expect(points.last).to eq([ "2026-02-11", 1075.0, 1075.0, 2.27 ])
  end

  it "applies the filters to the whole page, and passes them to the trades table" do
    get account_path(account, from: "2026-02-01", symbol: "EURUSD", robot_id: "", to: "")

    expect(net_profit).to eq("-USD 40.00")
    expect(response.parsed_body.at_css("turbo-frame#trades")["src"])
      .to eq(account_trades_path(account, from: "2026-02-01", symbol: "EURUSD"))
  end

  def tile_labels
    response.parsed_body.css("[aria-label='Performance summary'] dt").map(&:text)
  end

  def tile_value(label)
    response.parsed_body.css("[aria-label='Performance summary'] dt").find { _1.text == label }.next_element.text
  end

  it "shows the biggest trade below the return on the four-column grid" do
    get account_path(account)

    expect(tile_value("Biggest trade")).to eq("USD 100.00")
    expect(tile_labels.index("Biggest trade")).to eq(tile_labels.index("Return") + 4)
  end

  it "takes the biggest trade from the filtered trades only" do
    get account_path(account, from: "2026-02-01")

    expect(tile_value("Biggest trade")).to eq("USD 15.00")
  end

  it "has no biggest trade without a winning one" do
    get account_path(account, from: "2026-02-01", symbol: "EURUSD")

    expect(tile_value("Biggest trade")).to eq("–")
  end

  def net_profit_classes
    response.parsed_body.at_css("[data-testid=net-profit]").classes
  end

  it "colours a net profit green" do
    get account_path(account)

    expect(net_profit_classes).to include("text-green-700")
  end

  it "colours a filtered net loss red" do
    get account_path(account, from: "2026-02-01", symbol: "EURUSD")

    expect(net_profit_classes).to include("text-red-700")
  end

  it "colours a net profit of zero grey" do
    closed(account, "2026-03-01 12:00", 0)

    get account_path(account, from: "2026-03-01")

    expect(net_profit).to eq("USD 0.00")
    expect(net_profit_classes).to include("text-gray-500")
  end

  it "says so when nothing matches" do
    get account_path(account, symbol: "XAUUSD")

    expect(response.body).to include("No closed trades match these filters.")
  end

  it "explains why MT5's win rate differs when there are break-even trades" do
    closed(account, "2026-02-12 12:00", 0)

    get account_path(account)

    expect(response.body).to include("MT5 shows 75.0%: it counts 1 break-even trade as won.")
  end

  it "copes with an account without trades" do
    get account_path(create(:account))

    expect(response.body).to include("no closed trades yet")
  end
end
