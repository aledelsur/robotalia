module Metrics
  # Everything the dashboard shows for one filter.
  class Dashboard
    Result = Data.define(:summary, :curve, :months, :symbols, :robots)

    def initialize(filter)
      @filter = filter
    end

    def call
      Result.new(
        summary: Summary.new(@filter).call,
        curve: Curve.new(@filter).call,
        months: MonthlyReturns.new(@filter).call,
        symbols: Breakdown.new(@filter, by: :symbol).call,
        robots: Breakdown.new(@filter, by: :robot).call
      )
    end
  end
end
