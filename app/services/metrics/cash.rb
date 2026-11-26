module Metrics
  # The account's money around a filtered range. It always covers the whole account, so
  # that the return of one symbol or robot is measured against the capital it traded with.
  class Cash
    Result = Data.define(:opening_balance, :operations)

    def initialize(filter)
      @filter = filter
    end

    # opening_balance: the balance when the range starts. operations: the deposits,
    # withdrawals and other balance changes inside it, as [time, amount], oldest first.
    def call
      Result.new(
        opening_balance:,
        operations: account.balance_operations.where(executed_at: @filter.time_range)
          .order(:executed_at, :ticket).pluck(:executed_at, :amount)
      )
    end

    private
      def account
        @filter.account
      end

      def opening_balance
        return BigDecimal("0") unless @filter.starts_at

        earlier = ...@filter.starts_at
        account.balance_operations.where(executed_at: earlier).sum(:amount) +
          account.trades.where(closed_at: earlier).sum(:net_profit)
      end
  end
end
