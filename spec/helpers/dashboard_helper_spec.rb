require "rails_helper"

RSpec.describe DashboardHelper do
  describe "#net_profit_class" do
    it "is green for a profit" do
      expect(helper.net_profit_class(BigDecimal("0.01"))).to eq("text-green-700")
    end

    it "is red for a loss" do
      expect(helper.net_profit_class(BigDecimal("-0.01"))).to eq("text-red-700")
    end

    it "is grey for zero and for no figure" do
      expect([ BigDecimal("0"), nil ].map { helper.net_profit_class(_1) }).to all(eq("text-gray-500"))
    end
  end
end
