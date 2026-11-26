module Metrics
  # The filtered trades split by symbol or by robot, most profitable first. Robot rows
  # also split into long (buy) and short (sell) trades.
  class Breakdown
    Row = Data.define(:id, :name, :tally, :sides)
    SIDES = { "buy" => "Long", "sell" => "Short" }.freeze
    NO_ROBOT = "No robot"

    def initialize(filter, by:)
      raise ArgumentError, "unknown dimension #{by.inspect}" unless %i[symbol robot].include?(by)

      @filter = filter
      @by = by
    end

    def call
      rows = @by == :symbol ? symbol_rows : robot_rows
      rows.sort_by { [ -_1.tally.net_profit, _1.name ] }
    end

    private
      def symbol_rows
        grouped(:symbol).map do |(symbol), tally|
          Row.new(id: symbol, name: symbol, tally:, sides: [])
        end
      end

      def robot_rows
        names = @filter.account.robots.pluck(:id, :name).to_h
        sides = grouped(:robot_id, :side).group_by { |(robot_id, _), _| robot_id }

        grouped(:robot_id).map do |(robot_id), tally|
          split = sides.fetch(robot_id).sort_by { |(_, side), _| SIDES.keys.index(side) }
            .map { |(_, side), side_tally| Row.new(id: side, name: SIDES.fetch(side), tally: side_tally, sides: []) }
          Row.new(id: robot_id, name: names.fetch(robot_id, NO_ROBOT), tally:, sides: split)
        end
      end

      # [[group values, tally], ...]
      def grouped(*columns)
        @filter.trades.group(*columns).pluck(*columns, *Tally::COLUMNS)
          .map { |row| [ row.first(columns.size), Tally.from_row(row.drop(columns.size)) ] }
      end
  end
end
