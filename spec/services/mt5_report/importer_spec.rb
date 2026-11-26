require "rails_helper"

RSpec.describe Mt5Report::Importer do
  def import_report(**options)
    path = Rails.root.join("tmp/mt5_report_#{SecureRandom.hex(4)}.xlsx")
    Mt5ReportBuilder.new(**options).write(path)
    import = AccountImport.new
    import.report.attach(io: File.open(path), filename: "report.xlsx")
    import.save!
    described_class.new(import).call
    import.reload
  ensure
    FileUtils.rm_f(path)
  end

  it "creates the account from the report" do
    account = import_report.account

    expect(account).to have_attributes(login: "1234567", currency: "USD", server: "ExampleBroker-Demo",
                                       broker: "Example Broker", initial_balance: 1000, demo: false)
    expect(account.name).to eq("Example Broker ••••4567")
  end

  it "imports trades, deals and balance operations" do
    account = import_report.account

    expect(account.trades.count).to eq(4)
    expect(account.deals.count).to eq(9)
    expect(account.balance_operations.pluck(:amount)).to contain_exactly(1000, -100)
    expect(account.trades.sum(:net_profit)).to eq(BigDecimal("86.85"))
  end

  it "assigns each trade to the robot named by its entry deal" do
    account = import_report.account

    expect(account.robots.pluck(:name)).to contain_exactly("Trend_Long", "Range_Short")
    expect(account.trades.order(:position_id).map { _1.robot&.name })
      .to eq([ "Trend_Long", "Range_Short", nil, "Trend_Long" ])
  end

  it "counts trades and balance operations, and records row errors" do
    expect(import_report).to have_attributes(new_count: 6, updated_count: 0, skipped_count: 0, error_count: 1)
  end

  it "is idempotent" do
    import_report

    expect { @second = import_report }
      .to not_change(Trade, :count).and not_change(Deal, :count)
      .and not_change(BalanceOperation, :count).and not_change(Account, :count).and not_change(Robot, :count)
    expect(@second).to have_attributes(new_count: 0, updated_count: 0, skipped_count: 6)
  end

  it "updates a trade whose values changed, matched by position id" do
    import_report
    positions = Mt5ReportBuilder::POSITIONS.map(&:dup)
    positions.first[12] = 41.0

    second = import_report(positions:)

    expect(second).to have_attributes(new_count: 0, updated_count: 1, skipped_count: 5)
    expect(Trade.find_by!(position_id: 5001).profit).to eq(41)
  end

  it "keeps a trade's robot and a renamed robot when a later report lacks the entry deal" do
    account = import_report.account
    account.robots.find_by!(key: "trend_long").update!(name: "Trend follower")

    import_report(deals: [])

    expect(account.trades.find_by!(position_id: 5001).robot.name).to eq("Trend follower")
  end

  it "keeps other accounts separate" do
    import_report
    other = import_report(account: "7654321 (USD, ExampleBroker-Demo, demo, Hedge)")

    expect(Account.count).to eq(2)
    expect(other.new_count).to eq(6)
  end

  it "never imports into a demo account" do
    demo = create(:account, login: "1234567", server: "ExampleBroker-Demo", demo: true)

    expect(import_report.account).not_to eq(demo)
    expect(demo.trades).to be_empty
  end

  it "rejects an invalid record and imports the rest" do
    positions = Mt5ReportBuilder::POSITIONS.map(&:dup)
    positions.first[8] = "2020.01.01 00:00:00"

    import = import_report(positions:)

    expect(import.account.trades.count).to eq(3)
    expect(import.error_messages).to include(a_string_matching(/Position 5001: .*before the open time/))
  end
end
