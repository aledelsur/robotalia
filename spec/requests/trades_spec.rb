require "rails_helper"

RSpec.describe "Trades table" do
  let(:account) { create(:account) }
  let(:alpha) { create(:robot, account:, name: "Alpha") }
  let(:beta) { create(:robot, account:, name: "Beta") }

  def positions
    response.parsed_body.css("tr[data-position]").map { _1["data-position"].to_i }
  end

  context "signed in as the owner" do
    before do
      closed(account, "2026-03-02 12:00", 5, position_id: 1, symbol: "US30", robot: beta)
      closed(account, "2026-03-03 12:00", -8, position_id: 2, symbol: "EURUSD")
      closed(account, "2026-03-04 12:00", 20, position_id: 3, symbol: "GBPUSD", robot: alpha)
      sign_in
    end

    it "lists the newest first" do
      get account_trades_path(account)

      expect(positions).to eq([ 3, 2, 1 ])
    end

    it "sorts on the server, in either direction" do
      get account_trades_path(account, sort: "net_profit", direction: "asc")
      expect(positions).to eq([ 2, 1, 3 ])

      get account_trades_path(account, sort: "symbol", direction: "desc")
      expect(positions).to eq([ 1, 3, 2 ])
    end

    it "sorts by robot name, with trades without a robot last" do
      get account_trades_path(account, sort: "robot", direction: "asc")
      expect(positions).to eq([ 3, 1, 2 ])

      get account_trades_path(account, sort: "robot", direction: "desc")
      expect(positions).to eq([ 1, 3, 2 ])
    end

    it "falls back to the default order for a column it does not allow" do
      get account_trades_path(account, sort: "comment; DROP TABLE trades", direction: "sideways")

      expect(positions).to eq([ 3, 2, 1 ])
    end

    it "applies the dashboard filters, and keeps them in the sort links" do
      get account_trades_path(account, from: "2026-03-03", symbol: "EURUSD")

      expect(positions).to eq([ 2 ])
      link = response.parsed_body.at_css("th a")["href"]
      expect(link).to include("from=2026-03-03", "symbol=EURUSD", "sort=closed_at")
    end

    it "paginates, keeping the sort in the page links" do
      27.times { |n| closed(account, "2026-04-01 12:00", n + 100, position_id: 100 + n) }

      get account_trades_path(account, sort: "net_profit", direction: "asc")
      expect(positions.size).to eq(25)
      next_page = response.parsed_body.css("nav.pagy a[href]").last["href"]
      expect(next_page).to include("sort=net_profit", "direction=asc", "page=2")

      get next_page
      expect(positions).to eq([ 122, 123, 124, 125, 126 ])
    end

    it "shows an empty page for a page past the end" do
      get account_trades_path(account, page: 99)

      expect(response).to have_http_status(:ok)
      expect(positions).to be_empty
    end
  end

  it "shows the demo user demo accounts only" do
    sign_in create(:user, :demo)

    get account_trades_path(account)

    expect(response).to have_http_status(:not_found)
  end

  it "requires signing in" do
    get account_trades_path(account)

    expect(response).to redirect_to(new_session_path)
  end
end
