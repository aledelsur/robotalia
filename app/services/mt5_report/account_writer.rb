module Mt5Report
  # Writes a parsed report into an account. Safe to repeat: deals and balance operations
  # are matched by ticket, trades by position id. The counts cover trades and balance
  # operations; deals are the raw rows behind them.
  class AccountWriter
    Result = Data.define(:new_count, :updated_count, :skipped_count, :row_errors)

    def initialize(account, report)
      @account = account
      @report = report
    end

    def call
      @counts = Hash.new(0)
      @row_errors = @report.row_errors.dup

      Account.transaction do
        # One writer at a time per account.
        @account.lock!

        write_deals
        write_balance_operations
        write_trades
        update_initial_balance
      end

      Result.new(new_count: @counts[:new], updated_count: @counts[:updated],
                 skipped_count: @counts[:skipped], row_errors: @row_errors)
    end

    private
      # Records are built without the association, so a rejected one can't make the
      # account itself invalid.
      def write_deals
        existing = @account.deals.where(ticket: @report.deals.map(&:ticket)).index_by(&:ticket)

        @report.deals.each do |row|
          record = existing[row.ticket] ||= Deal.new(account: @account)
          save(record, row.to_h, "Deal #{row.ticket}")
        end
      end

      def write_balance_operations
        existing = @account.balance_operations
          .where(ticket: @report.balance_operations.map(&:ticket)).index_by(&:ticket)

        @report.balance_operations.each do |row|
          record = existing[row.ticket] ||= BalanceOperation.new(account: @account)
          count save(record, row.to_h, "Balance operation #{row.ticket}")
        end
      end

      def write_trades
        ids = @report.positions.map(&:position_id)
        existing = @account.trades.where(position_id: ids).index_by(&:position_id)
        entry_comments = @account.deals.where(direction: "in", order_ticket: ids).pluck(:order_ticket, :comment).to_h
        @robots = @account.robots.index_by(&:key)

        @report.positions.each do |row|
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

        @robots[key] ||= Robot.create!(account: @account, key:, name: comment.strip)
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
  end
end
