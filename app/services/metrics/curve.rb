module Metrics
  # How the account moved through a filtered range, one point per closed trade or balance
  # operation.
  #
  # balance: money in the account, including deposits and withdrawals.
  # equity: starting capital plus the profit of closed trades, so later cash flows don't
  #   move it. The report has no price history, so open positions are not valued.
  # drawdown: distance below the highest balance so far. A deposit or withdrawal moves that
  #   peak by the same amount, so cash flows never look like losses or recoveries.
  #
  # Starting capital is the balance when the range starts, plus any operation made before
  # its first trade (such as the opening deposit).
  class Curve
    Point = Data.define(:time, :balance, :equity, :drawdown, :drawdown_rate)
    Result = Data.define(:points, :max_drawdown, :max_drawdown_rate)

    def initialize(filter)
      @filter = filter
    end

    def call
      cash = Cash.new(@filter).call
      balance = equity = peak = cash.opening_balance
      trading = false
      points = []
      points << point(@filter.starts_at, balance, equity, peak) if @filter.starts_at && balance.nonzero?

      events(cash).each do |time, kind, amount|
        balance += amount
        if kind == :trade
          trading = true
          equity += amount
          peak = [ peak, balance ].max
        else
          equity += amount unless trading
          peak += amount
        end
        points << point(time, balance, equity, peak)
      end

      Result.new(
        points:,
        max_drawdown: points.map(&:drawdown).max || BigDecimal("0"),
        max_drawdown_rate: points.filter_map(&:drawdown_rate).max || 0.0
      )
    end

    private
      # Oldest first. At the same moment a balance operation comes before a trade.
      def events(cash)
        operations = cash.operations.map { |time, amount| [ time, :operation, amount ] }
        trades = @filter.trades.order(:closed_at, :position_id).pluck(:closed_at, :net_profit)
          .map { |time, amount| [ time, :trade, amount ] }

        (operations + trades).sort_by.with_index { |(time, _, _), index| [ time, index ] }
      end

      def point(time, balance, equity, peak)
        drawdown = peak - balance
        rate = drawdown.fdiv(peak) if peak.positive?
        Point.new(time:, balance:, equity:, drawdown:, drawdown_rate: rate)
      end
  end
end
