module Demo
  # Builds the synthetic demo account, the only account the public demo shows.
  # Everything is invented and fully determined by the seed. It produces the same value
  # objects as the MT5 parser, so demo data is stored exactly like imported data.
  class AccountGenerator
    LOGIN = "10000001"
    SERVER = "Robotalia-Synthetic"
    PERIOD = Date.new(2026, 5, 1)..Date.new(2026, 10, 30)
    BALANCE_OPERATIONS = [
      [ Date.new(2026, 5, 1), 10_000, "Deposit" ],
      [ Date.new(2026, 7, 1), 2_000, "Deposit" ],
      [ Date.new(2026, 9, 15), -1_500, "Withdrawal" ]
    ].freeze
    # A stretch in which every robot does worse, so the account has a visible drawdown.
    ROUGH_PATCH = Date.new(2026, 8, 3)..Date.new(2026, 8, 28)
    ROUGH_PATCH_PENALTY = 0.12
    RISK_PER_TRADE = 70

    # price: starting level. stop: typical stop distance. contract: account currency per
    # 1.0 price move per lot. commission: round trip per lot.
    Instrument = Data.define(:price, :stop, :digits, :contract, :commission)
    INSTRUMENTS = {
      "EURUSD" => Instrument.new(price: 1.0850, stop: 0.0022, digits: 5, contract: 100_000, commission: 7),
      "GBPUSD" => Instrument.new(price: 1.2700, stop: 0.0028, digits: 5, contract: 100_000, commission: 7),
      "XAUUSD" => Instrument.new(price: 2900.0, stop: 6.5, digits: 2, contract: 100, commission: 7),
      "US30" => Instrument.new(price: 42_000.0, stop: 110.0, digits: 2, contract: 1, commission: 0),
      "NAS100" => Instrument.new(price: 21_000.0, stop: 70.0, digits: 2, contract: 1, commission: 0)
    }.freeze

    # Invented robots, commented the way a two-direction robot labels its trades.
    # frequency: chance of each of two daily entries. reward: typical win, in multiples of risk.
    Strategy = Data.define(:comment, :symbols, :frequency, :win_rate, :reward)
    STRATEGIES = [
      Strategy.new(comment: "M3_EURUSD", symbols: %w[EURUSD], frequency: 0.55, win_rate: 0.40, reward: 1.65),
      Strategy.new(comment: "M4_GBPUSD", symbols: %w[GBPUSD], frequency: 0.65, win_rate: 0.55, reward: 0.82),
      Strategy.new(comment: "M5", symbols: %w[XAUUSD NAS100], frequency: 0.50, win_rate: 0.35, reward: 1.85),
      # Deliberately a losing robot: something for the analysis to find.
      Strategy.new(comment: "M7_US30", symbols: %w[US30], frequency: 0.60, win_rate: 0.45, reward: 0.75)
    ].freeze

    def initialize(seed: 2026)
      @seed = seed
    end

    def call
      data = report

      Account.transaction do
        account = Account.create_with(name: "Demo account", broker: data.account.broker, currency: "USD")
          .find_or_create_by!(login: LOGIN, server: SERVER, demo: true)
        remove_stale_rows(account, data)
        result = Mt5Report::AccountWriter.new(account, data).call
        raise "Demo data is invalid: #{result.row_errors.first}" if result.row_errors.any?
        account.robots.where.missing(:trades).delete_all

        account
      end
    end

    def report
      @random = Random.new(@seed)
      positions, comments = generate_positions

      Mt5Report::Parser::Report.new(
        account: Mt5Report::Parser::AccountInfo.new(
          login: LOGIN, currency: "USD", server: SERVER, broker: "Synthetic data"
        ),
        positions:,
        **ledger(positions, comments),
        row_errors: []
      )
    end

    private
      def remove_stale_rows(account, data)
        account.trades.where.not(position_id: data.positions.map(&:position_id)).delete_all
        account.deals.where.not(ticket: data.deals.map(&:ticket)).delete_all
        account.balance_operations.where.not(ticket: data.balance_operations.map(&:ticket)).delete_all
      end

      def generate_positions
        prices = INSTRUMENTS.transform_values(&:price)
        positions = []
        comments = {}

        PERIOD.reject(&:on_weekend?).each do |day|
          INSTRUMENTS.each { |symbol, instrument| prices[symbol] += gaussian * instrument.stop * 0.8 }

          entries = STRATEGIES.flat_map do |strategy|
            2.times.filter_map { [ strategy, entry_time(day) ] if @random.rand < strategy.frequency }
          end

          entries.sort_by(&:last).each do |strategy, opened_at|
            id = 700_000_000 + positions.size
            positions << position(id, strategy, opened_at, prices)
            comments[id] = "#{strategy.comment}_#{positions.last.side == "buy" ? "Long" : "Short"}"
          end
        end

        [ positions, comments ]
      end

      def entry_time(day)
        Time.utc(day.year, day.month, day.day, 7) + @random.rand(10 * 3600)
      end

      def position(id, strategy, opened_at, prices)
        symbol = strategy.symbols.sample(random: @random)
        instrument = INSTRUMENTS.fetch(symbol)
        side = @random.rand < 0.5 ? "buy" : "sell"
        direction = side == "buy" ? 1 : -1
        entry = (prices[symbol] + gaussian * instrument.stop * 0.3).round(instrument.digits)
        stop_distance = instrument.stop * between(0.8, 1.2)
        volume = [ (RISK_PER_TRADE / (stop_distance * instrument.contract)).round(2), 0.01 ].max

        win_rate = strategy.win_rate
        win_rate -= ROUGH_PATCH_PENALTY if ROUGH_PATCH.cover?(opened_at.to_date)
        multiple = @random.rand < win_rate ? strategy.reward * between(0.6, 1.4) : -between(0.55, 1.05)
        exit_price = (entry + direction * multiple * stop_distance).round(instrument.digits)

        closed_at = closing_time(opened_at)
        nights = (closed_at.to_date - opened_at.to_date).to_i

        Mt5Report::Parser::Position.new(
          position_id: id, symbol:, side:, volume: decimal(volume), opened_at:, closed_at:,
          open_price: decimal(entry, instrument.digits), close_price: decimal(exit_price, instrument.digits),
          stop_loss: decimal(entry - direction * stop_distance, instrument.digits),
          take_profit: decimal(entry + direction * stop_distance * strategy.reward * 1.4, instrument.digits),
          commission: decimal(-volume * instrument.commission), swap: decimal(-volume * nights * 3.5),
          profit: decimal((exit_price - entry) * direction * volume * instrument.contract)
        )
      end

      # Usually the same day; sometimes the next trading day.
      def closing_time(opened_at)
        closed_at = opened_at + 5 * 60 + @random.rand(4 * 3600)
        return closed_at unless @random.rand < 0.06

        day = opened_at.to_date + 1
        day += 1 while day.on_weekend?
        return closed_at if day > PERIOD.last

        Time.utc(day.year, day.month, day.day, 7) + @random.rand(8 * 3600)
      end

      # The deals and balance operations behind the positions, ticketed in time order with a
      # running balance, as the Deals section of a report lists them.
      def ledger(positions, comments)
        events = BALANCE_OPERATIONS.map { |day, amount, label| [ Time.utc(day.year, day.month, day.day, 6), :balance, amount, label ] }
        positions.each do |position|
          events << [ position.opened_at, :in, position, comments.fetch(position.position_id) ]
          events << [ position.closed_at, :out, position, nil ]
        end

        deals = []
        operations = []
        balance = BigDecimal("0")

        events.sort_by.with_index { |event, index| [ event.first, index ] }.each_with_index do |(time, type, subject, comment), index|
          ticket = 800_000_000 + index
          if type == :balance
            balance += subject
            operations << Mt5Report::Parser::BalanceOperation.new(
              ticket:, executed_at: time, kind: "balance", amount: decimal(subject), comment:
            )
          else
            closing = type == :out
            balance += subject.profit + subject.commission + subject.swap if closing
            deals << deal(ticket, subject, time, closing, comment, balance)
          end
        end

        { deals:, balance_operations: operations }
      end

      # Commission and swap are booked on the closing deal.
      def deal(ticket, position, time, closing, comment, balance)
        opposite = position.side == "buy" ? "sell" : "buy"
        zero = BigDecimal("0")

        Mt5Report::Parser::Deal.new(
          ticket:, executed_at: time, symbol: position.symbol, volume: position.volume, balance:, comment:,
          order_ticket: closing ? position.position_id + 50_000_000 : position.position_id,
          side: closing ? opposite : position.side, direction: closing ? "out" : "in",
          price: closing ? position.close_price : position.open_price,
          commission: closing ? position.commission : zero, swap: closing ? position.swap : zero,
          fee: zero, profit: closing ? position.profit : zero
        )
      end

      def between(low, high)
        low + @random.rand * (high - low)
      end

      # Box-Muller transform.
      def gaussian
        Math.sqrt(-2 * Math.log(1 - @random.rand)) * Math.cos(2 * Math::PI * @random.rand)
      end

      def decimal(value, scale = 2)
        BigDecimal(value.to_s).round(scale)
      end
  end
end
