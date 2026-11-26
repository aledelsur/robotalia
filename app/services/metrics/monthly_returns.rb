module Metrics
  # Net profit and return of each month that has closed trades, by closing time (server
  # time). A month cut by the date range only counts the days inside it.
  class MonthlyReturns
    Month = Data.define(:month, :trades, :net_profit, :return_rate)
    BY_MONTH = Arel.sql("date_trunc('month', trades.closed_at)")

    def initialize(filter)
      @filter = filter
    end

    def call
      cash = Cash.new(@filter).call
      account_profit = by_month(@filter.account.trades.where(closed_at: @filter.time_range))
        .sum(:net_profit)
      balance = cash.opening_balance
      operations = cash.operations.group_by { |time, _| time.to_date.beginning_of_month }
      selected = by_month(@filter.trades)
        .pluck(BY_MONTH, Arel.sql("COUNT(*)"), Arel.sql("SUM(trades.net_profit)"))
        .to_h { |time, count, net| [ time.to_date, [ count, net ] ] }
      account_profit = account_profit.transform_keys(&:to_date)

      # Every month in which the account's balance changed, to carry the balance forward.
      (account_profit.keys | operations.keys).sort.filter_map do |month|
        amounts = operations.fetch(month, []).map(&:last)
        opening = balance
        balance += account_profit.fetch(month, 0) + amounts.sum
        next unless selected.key?(month)

        count, net = selected.fetch(month)
        Month.new(month:, trades: count, net_profit: net,
                  return_rate: ReturnRate.of(net, opening_balance: opening, deposits: amounts.select(&:positive?).sum))
      end
    end

    private
      def by_month(trades)
        trades.group(BY_MONTH)
      end
  end
end
