require "rails_helper"

RSpec.describe Mt5Report::Parser do
  subject(:report) { described_class.new(file_fixture("mt5_report_sample.xlsx")).call }

  def build_report(**options)
    path = Rails.root.join("tmp/mt5_report_#{SecureRandom.hex(4)}.xlsx")
    described_class.new(Mt5ReportBuilder.new(**options).write(path)).call
  ensure
    FileUtils.rm_f(path)
  end

  it "reads the account from the header, without the owner's name" do
    expect(report.account.to_h).to eq(
      login: "1234567", currency: "USD", server: "ExampleBroker-Demo", broker: "Example Broker"
    )
  end

  it "reads closed positions with exact decimal amounts" do
    position = report.positions.find { _1.position_id == 5002 }

    expect(position).to have_attributes(
      symbol: "GBPUSD", side: "sell", volume: BigDecimal("0.2"),
      opened_at: Time.utc(2026, 3, 3, 10), closed_at: Time.utc(2026, 3, 4, 8),
      open_price: BigDecimal("1.27"), close_price: BigDecimal("1.271"),
      stop_loss: BigDecimal("1.271"), take_profit: BigDecimal("1.267"),
      commission: BigDecimal("-1.4"), swap: BigDecimal("-0.35"), profit: BigDecimal("-20")
    )
  end

  it "merges the partial closes of one position" do
    expect(report.positions.map(&:position_id)).to eq([ 5001, 5002, 5003, 5004 ])
    expect(report.positions.last).to have_attributes(
      volume: BigDecimal("0.2"), profit: BigDecimal("60"), commission: BigDecimal("-0.7"),
      close_price: BigDecimal("1.093"), closed_at: Time.utc(2026, 3, 6, 11)
    )
  end

  it "separates trading deals from balance operations" do
    expect(report.deals.size).to eq(9)
    expect(report.balance_operations.map(&:amount)).to eq([ 1000, -100 ])
    expect(report.deals.first).to have_attributes(
      ticket: 9001, order_ticket: 5001, side: "buy", direction: "in", comment: "Trend_Long"
    )
  end

  it "reports a malformed row and keeps reading" do
    expect(report.row_errors).to contain_exactly(a_string_matching(/\APositions row 13: .*time/))
  end

  it "rejects a file that is not a spreadsheet" do
    file = Tempfile.new([ "bad", ".xlsx" ]).tap { _1.write("<html></html>") && _1.flush }

    expect { described_class.new(file.path).call }.to raise_error(described_class::InvalidReport)
  end

  it "rejects a spreadsheet without the expected sections" do
    allow_any_instance_of(Mt5ReportBuilder).to receive(:rows).and_return([ [ "Hello" ] ])

    expect { build_report }.to raise_error(described_class::InvalidReport, /MT5/)
  end

  it "rejects unexpected columns instead of misreading them" do
    stub_const("Mt5ReportBuilder::DEAL_HEADER", Mt5ReportBuilder::DEAL_HEADER.reverse)

    expect { build_report }.to raise_error(described_class::InvalidReport, /Deals columns/)
  end
end
