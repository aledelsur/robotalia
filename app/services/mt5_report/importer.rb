module Mt5Report
  # Imports an uploaded report into its account, found or created from the report header.
  # Re-importing is safe: deals and balance operations are matched by ticket, trades by
  # position id. The counts cover trades and balance operations; deals are the raw rows
  # behind them.
  class Importer
    MAX_ERROR_MESSAGES = 50

    def initialize(account_import)
      @account_import = account_import
    end

    def call
      report = @account_import.report.open { |file| Parser.new(file.path).call }
      @counts = Hash.new(0)
      @row_errors = report.row_errors.dup

      Account.transaction do
        @account = find_or_create_account(report.account)
        # One import at a time per account.
        @account.lock!

        import_deals(report.deals)
        import_balance_operations(report.balance_operations)
        import_trades(report.positions)
        update_initial_balance
        record_results
      end

      @account_import
    end

    private
      def find_or_create_account(info)
        Account.create_with(currency: info.currency, broker: info.broker, name: account_name(info))
          .find_or_create_by!(login: info.login, server: info.server, demo: false)
      end

      def account_name(info)
        "#{info.broker.presence || "MT5"} #{Account.new(login: info.login).masked_login}"
      end

      def import_deals(deals)
        existing = @account.deals.where(ticket: deals.map(&:ticket)).index_by(&:ticket)

        deals.each do |row|
          record = existing[row.ticket] ||= Deal.new(account: @account)
          save(record, row.to_h, "Deal #{row.ticket}")
        end
      end

      def import_balance_operations(operations)
        existing = @account.balance_operations.where(ticket: operations.map(&:ticket)).index_by(&:ticket)

        operations.each do |row|
          record = existing[row.ticket] ||= BalanceOperation.new(account: @account)
          count save(record, row.to_h, "Balance operation #{row.ticket}")
        end
      end

      def import_trades(positions)
        ids = positions.map(&:position_id)
        existing = @account.trades.where(position_id: ids).index_by(&:position_id)
        entry_comments = @account.deals.where(direction: "in", order_ticket: ids).pluck(:order_ticket, :comment).to_h
        @robots = @account.robots.index_by(&:key)

        positions.each do |row|
          record = existing[row.position_id] || Trade.new(account: @account)
          attributes = row.to_h
          # A report without the entry deal must not erase what an earlier one told us.
          if entry_comments.key?(row.position_id)
            comment = entry_comments[row.position_id]
            attributes.merge!(comment:, robot: robot_for(comment))
          end
          count save(record, attributes, "Position #{row.position_id}")
        end
      end

      def robot_for(comment)
        key = Robot.key_for(comment)
        return unless key

        @robots[key] ||= @account.robots.create!(key:, name: comment.strip)
      end

      # Returns :new, :updated or :skipped, or nil if the record is invalid.
      def save(record, attributes, label)
        record.assign_attributes(attributes)

        unless record.valid?
          @row_errors << "#{label}: #{record.errors.full_messages.to_sentence}"
          return
        end

        outcome = if record.new_record? then :new
        elsif record.changed? then :updated
        else :skipped
        end
        record.save!(validate: false) unless outcome == :skipped
        outcome
      end

      def count(outcome)
        @counts[outcome] += 1 if outcome
      end

      # The deposit that opened the account: a first balance operation that precedes every deal.
      def update_initial_balance
        opening = @account.balance_operations.order(:executed_at, :ticket).first
        first_deal_at = @account.deals.minimum(:executed_at)
        return unless opening && (first_deal_at.nil? || opening.executed_at <= first_deal_at)

        @account.update!(initial_balance: opening.amount)
      end

      def record_results
        @account_import.update!(
          account: @account,
          new_count: @counts[:new], updated_count: @counts[:updated], skipped_count: @counts[:skipped],
          error_count: @row_errors.size, error_messages: @row_errors.first(MAX_ERROR_MESSAGES)
        )
      end
  end
end
