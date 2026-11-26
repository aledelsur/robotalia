module Metrics
  # The one definition of a return, used for the whole range and for each month:
  #
  #   net profit / (balance when the period starts + deposits during the period)
  #
  # Nil when there was no capital to earn on.
  module ReturnRate
    def self.of(net_profit, opening_balance:, deposits:)
      capital = opening_balance + deposits
      net_profit / capital if capital.positive?
    end
  end
end
