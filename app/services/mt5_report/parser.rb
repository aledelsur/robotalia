module Mt5Report
  # Reads the .xlsx "Trade History Report" that MetaTrader 5 exports into plain value objects.
  # No database access.
  #
  # The report is one sheet. A section is a title row, a header row and data rows, ending at an
  # empty first cell or at the next title.
  #
  #   Header     "Account:" -> "<login> (<currency>, <server>, <type>, <mode>)", "Company:" -> broker
  #   Positions  closed positions. MT5 pairs each entry with its exit here, so trades come from it.
  #   Deals      every execution plus balance operations. Deals name their order, not their
  #              position; the entry order's number is the position id, and its comment names
  #              the robot. The report has no magic number.
  #   Orders and Results are not imported.
  #
  # Times are broker server time with no zone. They are kept as written, labelled UTC.
  class Parser
    class InvalidReport < StandardError; end
    class RowError < StandardError; end

    AccountInfo = Data.define(:login, :currency, :server, :broker)
    Position = Data.define(:position_id, :symbol, :side, :volume, :opened_at, :closed_at,
                           :open_price, :close_price, :stop_loss, :take_profit, :commission, :swap, :profit)
    Deal = Data.define(:ticket, :order_ticket, :executed_at, :symbol, :side, :direction, :volume, :price,
                       :commission, :fee, :swap, :profit, :balance, :comment)
    BalanceOperation = Data.define(:ticket, :executed_at, :kind, :amount, :comment)
    Report = Data.define(:account, :positions, :deals, :balance_operations, :row_errors)

    SECTION_TITLES = [ "Positions", "Orders", "Deals", "Open Positions", "Working Orders", "Results" ].freeze
    COLUMNS = {
      "Positions" => [ "Time", "Position", "Symbol", "Type", "Volume", "Price", "S / L", "T / P",
                       "Time", "Price", "Commission", "Swap", "Profit" ],
      "Deals" => [ "Time", "Deal", "Symbol", "Type", "Direction", "Volume", "Price", "Order",
                   "Commission", "Fee", "Swap", "Profit", "Balance", "Comment" ]
    }.freeze
    TIME_FORMAT = /\A(\d{4})\.(\d{2})\.(\d{2}) (\d{2}):(\d{2}):(\d{2})\z/

    def initialize(path)
      @path = path.to_s
    end

    def call
      @rows = read_rows
      @row_errors = []
      account = parse_account
      positions = merge_partial_closes(parse_section("Positions") { parse_position(_1) })
      balance_rows, deal_rows = parse_section("Deals") { parse_deal_row(_1) }
        .partition { _1.is_a?(BalanceOperation) }

      Report.new(account:, positions:, deals: deal_rows, balance_operations: balance_rows, row_errors: @row_errors)
    end

    private
      def read_rows
        sheet = Roo::Excelx.new(@path).sheet(0)
        (1..sheet.last_row.to_i).map { sheet.row(_1) }
      rescue Zip::Error, Nokogiri::XML::SyntaxError, Roo::Error, Roo::FileNotFound, ArgumentError, IOError => e
        raise InvalidReport, "The file could not be read as an .xlsx spreadsheet (#{e.class.name.demodulize})."
      end

      def parse_account
        match = header_value("Account:").to_s.match(/\A(\d+)\s*\(([^)]*)\)/)
        raise InvalidReport, "This is not an MT5 trade history report: no account line." unless match

        currency, server = match[2].split(",").map(&:strip)
        AccountInfo.new(login: match[1], currency:, server: server.to_s, broker: header_value("Company:"))
      end

      def header_value(label)
        row = @rows.first(10).find { _1[0] == label }
        row && row.drop(1).compact.first
      end

      def parse_section(title)
        start = @rows.index { _1[0] == title && _1.compact.size == 1 }
        raise InvalidReport, "This is not an MT5 trade history report: no #{title} section." unless start

        columns = COLUMNS.fetch(title)
        unless @rows[start + 1]&.first(columns.size) == columns
          raise InvalidReport, "Unexpected #{title} columns. Export the report with MT5 set to English."
        end

        records = []
        ((start + 2)...@rows.size).each do |index|
          row = @rows[index]
          break if row[0].blank? || SECTION_TITLES.include?(row[0])

          begin
            records << yield(row)
          rescue RowError => e
            @row_errors << "#{title} row #{index + 1}: #{e.message}"
          end
        end
        records
      end

      def parse_position(row)
        Position.new(
          opened_at: time(row[0]), position_id: integer(row[1], "position"), symbol: text(row[2], "symbol"),
          side: side(row[3]), volume: decimal(row[4], "volume"), open_price: decimal(row[5], "open price", 5),
          stop_loss: price_or_nil(row[6], "S / L"), take_profit: price_or_nil(row[7], "T / P"),
          closed_at: time(row[8]), close_price: decimal(row[9], "close price", 5),
          commission: decimal(row[10], "commission"), swap: decimal(row[11], "swap"),
          profit: decimal(row[12], "profit")
        )
      end

      def parse_deal_row(row)
        executed_at = time(row[0])
        ticket = integer(row[1], "deal")
        kind = text(row[3], "type")
        comment = row[13].to_s.strip.presence

        unless %w[buy sell].include?(kind)
          return BalanceOperation.new(ticket:, executed_at:, kind:, amount: decimal(row[11], "amount"), comment:)
        end

        Deal.new(
          ticket:, executed_at:, comment:, side: kind, symbol: text(row[2], "symbol"),
          direction: text(row[4], "direction"), volume: decimal(row[5], "volume"),
          price: decimal(row[6], "price", 5), order_ticket: integer(row[7], "order"),
          commission: decimal(row[8], "commission"), fee: decimal(row[9], "fee"),
          swap: decimal(row[10], "swap"), profit: decimal(row[11], "profit"),
          balance: decimal(row[12], "balance")
        )
      end

      # A position closed in parts may be listed once per part. Add the parts together and
      # weight the close price by volume.
      def merge_partial_closes(positions)
        positions.uniq.group_by(&:position_id).values.map do |parts|
          next parts.first if parts.one?

          volume = parts.sum(&:volume)
          parts.first.with(
            volume:,
            closed_at: parts.map(&:closed_at).max,
            close_price: (parts.sum { _1.close_price * _1.volume } / volume).round(5),
            commission: parts.sum(&:commission), swap: parts.sum(&:swap), profit: parts.sum(&:profit)
          )
        end
      end

      def time(value)
        match = TIME_FORMAT.match(value.to_s.strip)
        raise RowError, "invalid time #{value.inspect}" unless match

        Time.utc(*match.captures.map(&:to_i))
      rescue ArgumentError
        raise RowError, "invalid time #{value.inspect}"
      end

      def integer(value, name)
        Integer(value.to_s, 10, exception: false) || raise(RowError, "invalid #{name} number #{value.inspect}")
      end

      # Cells are floats or strings; going through a string keeps the digits MT5 wrote.
      def decimal(value, name, scale = 2)
        number = BigDecimal(value.to_s.delete(" "), exception: false)
        raise RowError, "invalid #{name} #{value.inspect}" unless number

        number.round(scale)
      end

      def price_or_nil(value, name)
        return if value.blank?

        price = decimal(value, name, 5)
        price unless price.zero?
      end

      def text(value, name)
        value.to_s.strip.presence || raise(RowError, "missing #{name}")
      end

      def side(value)
        %w[buy sell].include?(value) ? value : raise(RowError, "unknown type #{value.inspect}")
      end
  end
end
