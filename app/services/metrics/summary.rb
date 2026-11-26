module Metrics
  # The headline figures of a filtered range.
  class Summary
    Result = Data.define(:tally, :return_rate, :longest_losing_streak) do
      delegate(*Tally.members, :break_even, :win_rate, :mt5_win_rate, :profit_factor,
               :expectancy, :average_win, :average_loss, to: :tally)
    end

    def initialize(filter)
      @filter = filter
    end

    def call
      tally = Tally.from_row(@filter.trades.pick(*Tally::COLUMNS))
      cash = Cash.new(@filter).call

      Result.new(
        tally:,
        return_rate: ReturnRate.of(tally.net_profit, opening_balance: cash.opening_balance,
                                   deposits: cash.operations.map(&:last).select(&:positive?).sum),
        longest_losing_streak:
      )
    end

    private
      # Consecutive losses in closing order. A break-even trade ends a streak.
      def longest_losing_streak
        @filter.trades.order(:closed_at, :position_id).pluck(:net_profit)
          .chunk(&:negative?)
          .filter_map { |losing, run| run.size if losing }
          .max || 0
      end
  end
end
