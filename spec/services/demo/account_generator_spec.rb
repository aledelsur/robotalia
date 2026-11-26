require "rails_helper"

RSpec.describe Demo::AccountGenerator do
  describe "the generated data" do
    before(:context) { @report = described_class.new.report }

    let(:positions) { @report.positions }
    let(:comments) { @report.deals.select { _1.direction == "in" }.to_h { [ _1.order_ticket, _1.comment ] } }
    let(:nets) { positions.sort_by(&:closed_at).map { _1.profit + _1.commission + _1.swap } }

    it "is deterministic" do
      expect(described_class.new.report).to eq(@report)
    end

    it "covers about six months, five symbols and four robots" do
      expect(positions.size).to be_between(550, 700)
      expect((positions.map(&:closed_at).max - positions.map(&:opened_at).min) / 1.day).to be_between(175, 186)
      expect(positions.map(&:symbol).uniq.size).to eq(5)
      expect(comments.values.uniq.size).to eq(4)
    end

    it "trades on weekdays only, and closes after it opens" do
      expect(positions.flat_map { [ _1.opened_at, _1.closed_at ] }).to all(satisfy { !_1.saturday? && !_1.sunday? })
      expect(positions).to all(satisfy { _1.closed_at > _1.opened_at })
    end

    it "keeps profit consistent with the direction of the price move" do
      expect(positions).to all(satisfy { |position|
        move = (position.close_price - position.open_price) * (position.side == "buy" ? 1 : -1)
        (move <=> 0) == (position.profit <=> 0)
      })
    end

    it "looks like a believable account: modest gain, real drawdown, mixed robots" do
      balance = peak = BigDecimal("10000")
      drawdown = nets.map do |net|
        balance += net
        peak = [ peak, balance ].max
        (peak - balance) / peak
      end.max
      by_robot = positions.group_by { comments[_1.position_id] }
        .transform_values { |list| list.sum { _1.profit + _1.commission + _1.swap } }

      expect(nets.sum / 10_000).to be_between(0.05, 0.6)
      expect(nets.count(&:positive?).fdiv(nets.size)).to be_between(0.4, 0.65)
      expect(drawdown).to be_between(0.05, 0.25)
      expect(by_robot.values).to include(be_negative)
    end

    it "includes a later deposit and a withdrawal" do
      expect(@report.balance_operations.map { _1.amount.to_i }).to eq([ 10_000, 2_000, -1_500 ])
    end
  end

  describe "#call" do
    it "creates the demo account, and changes nothing when run again" do
      account = described_class.new.call
      ids = account.trades.order(:id).ids

      expect(account).to have_attributes(demo: true, initial_balance: 10_000)
      expect(account.robots.count).to eq(4)
      expect { described_class.new.call }.to not_change(Account, :count).and not_change(Deal, :count)
      expect(account.trades.order(:id).ids).to eq(ids)
    end

    it "removes rows that are no longer generated" do
      account = described_class.new.call
      stale = create(:trade, account:, position_id: 1)

      described_class.new.call

      expect(Trade.exists?(stale.id)).to be(false)
    end

    it "leaves real accounts alone" do
      real = create(:account)
      trade = create(:trade, account: real)

      described_class.new.call

      expect(trade.reload.account).to eq(real)
    end
  end
end
