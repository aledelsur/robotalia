module Metrics
  # Counts and sums over a set of closed trades, and the ratios they give. A win has a
  # positive net profit (profit + commission + swap); a trade at exactly zero is break-even.
  Tally = Data.define(:trades, :wins, :losses, :net_profit, :gross_profit, :gross_loss,
                      :largest_win, :largest_loss) do
    def break_even
      trades - wins - losses
    end

    def win_rate
      wins.fdiv(trades) if trades.positive?
    end

    # MT5 reports break-even trades as "profit trades".
    def mt5_win_rate
      (wins + break_even).fdiv(trades) if trades.positive?
    end

    # Undefined without losses.
    def profit_factor
      gross_profit / gross_loss.abs unless gross_loss.zero?
    end

    def expectancy
      net_profit / trades if trades.positive?
    end

    def average_win
      gross_profit / wins if wins.positive?
    end

    def average_loss
      gross_loss / losses if losses.positive?
    end
  end

  class Tally
    # In the order of the members above, so a plucked row builds a tally.
    COLUMNS = [
      "COUNT(*)",
      "COUNT(*) FILTER (WHERE net_profit > 0)",
      "COUNT(*) FILTER (WHERE net_profit < 0)",
      "COALESCE(SUM(net_profit), 0)",
      "COALESCE(SUM(net_profit) FILTER (WHERE net_profit > 0), 0)",
      "COALESCE(SUM(net_profit) FILTER (WHERE net_profit < 0), 0)",
      "MAX(net_profit) FILTER (WHERE net_profit > 0)",
      "MIN(net_profit) FILTER (WHERE net_profit < 0)"
    ].map { Arel.sql(_1) }.freeze

    def self.from_row(row)
      new(**members.zip(row).to_h)
    end
  end
end
