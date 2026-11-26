require "rails_helper"

RSpec.describe "Trading models" do
  describe Account do
    it "shows only the last digits of the login" do
      expect(build(:account, login: "12345678").masked_login).to eq("••••5678")
    end

    it "requires a three-letter currency" do
      expect(build(:account, currency: "dollars")).not_to be_valid
    end

    it "can be destroyed with its trades and robots" do
      robot = create(:robot)
      create(:trade, account: robot.account, robot: robot)

      expect { robot.account.destroy! }.to change(Trade, :count).by(-1).and change(Robot, :count).by(-1)
    end
  end

  describe Trade do
    it "computes net profit from profit, commission and swap" do
      expect(create(:trade, profit: 10, commission: -0.7, swap: -0.2).net_profit).to eq(BigDecimal("9.1"))
    end

    it "cannot close before it opens" do
      expect(build(:trade, closed_at: Time.utc(2020, 1, 1))).not_to be_valid
    end

    it "is unique per account and position id" do
      trade = create(:trade)
      copy = build(:trade, account: trade.account, position_id: trade.position_id)

      expect { copy.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe Robot do
    it "derives a key from the trade comment" do
      expect(described_class.key_for("  Trend_Long ")).to eq("trend_long")
    end

    it "ignores blank comments and MT5 stop or target comments" do
      expect([ nil, "", "[sl 1.1000]", "[tp 1.2000]" ].map { described_class.key_for(_1) }).to all(be_nil)
    end
  end

  describe AccountImport do
    it "accepts only .xlsx reports" do
      import = described_class.new
      import.report.attach(io: StringIO.new("<html>"), filename: "report.html")

      expect(import).not_to be_valid
    end

    it "requires a report" do
      expect(described_class.new).not_to be_valid
    end
  end
end
