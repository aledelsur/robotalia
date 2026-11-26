module Mt5Report
  # Imports an uploaded report into its account, found or created from the report header.
  class Importer
    MAX_ERROR_MESSAGES = 50

    def initialize(account_import)
      @account_import = account_import
    end

    def call
      report = @account_import.report.open { |file| Parser.new(file.path).call }

      Account.transaction do
        account = find_or_create_account(report.account)
        result = AccountWriter.new(account, report).call

        @account_import.update!(
          account:,
          new_count: result.new_count, updated_count: result.updated_count,
          skipped_count: result.skipped_count, error_count: result.row_errors.size,
          error_messages: result.row_errors.first(MAX_ERROR_MESSAGES)
        )
      end

      @account_import
    end

    private
      # Real reports never go into a demo account.
      def find_or_create_account(info)
        Account.create_with(currency: info.currency, broker: info.broker, name: account_name(info))
          .find_or_create_by!(login: info.login, server: info.server, demo: false)
      end

      def account_name(info)
        "#{info.broker.presence || "MT5"} #{Account.new(login: info.login).masked_login}"
      end
  end
end
