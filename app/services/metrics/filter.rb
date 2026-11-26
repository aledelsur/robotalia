module Metrics
  # The slice of an account being measured: a range of closing dates (server time, both
  # ends included), and optionally one symbol or robot.
  Filter = Data.define(:account, :from, :to, :symbol, :robot_id) do
    def initialize(account:, from: nil, to: nil, symbol: nil, robot_id: nil)
      super
    end

    # Anything that does not parse is ignored rather than rejected.
    def self.from_params(account, params)
      new(
        account:, from: parse_date(params[:from]), to: parse_date(params[:to]),
        symbol: params[:symbol].to_s.presence, robot_id: Integer(params[:robot_id].to_s, 10, exception: false)
      )
    end

    def self.parse_date(value)
      date = Date.strptime(value.to_s, "%Y-%m-%d")
      date if date.year.between?(1970, 2100)
    rescue Date::Error
      nil
    end
    private_class_method :parse_date

    def trades
      scope = account.trades.where(closed_at: time_range)
      scope = scope.where(symbol:) if symbol
      scope = scope.where(robot_id:) if robot_id
      scope
    end

    def starts_at
      from&.in_time_zone("UTC")
    end

    # Exclusive: midnight after the last day.
    def ends_at
      to&.next_day&.in_time_zone("UTC")
    end

    def time_range
      starts_at...ends_at
    end

    def to_params
      { from: from&.iso8601, to: to&.iso8601, symbol:, robot_id: }.compact
    end

    def active?
      to_params.any?
    end
  end
end
