class ImportAccountReportJob < ApplicationJob
  queue_as :default

  def perform(account_import)
    change_status(account_import, status: :processing, error_messages: [])
    Mt5Report::Importer.new(account_import).call
    change_status(account_import, status: :completed, finished_at: Time.current)
  rescue Mt5Report::Parser::InvalidReport => e
    fail_import(account_import, e.message)
  rescue StandardError
    # The details go to the job's error log, not to the page.
    fail_import(account_import, "The import stopped on an unexpected error.")
    raise
  end

  private
    def fail_import(account_import, message)
      account_import.reload
      change_status(account_import, status: :failed, finished_at: Time.current, error_messages: [ message ])
    end

    def change_status(account_import, **attributes)
      account_import.update!(attributes)
      Turbo::StreamsChannel.broadcast_replace_to(
        account_import,
        target: ActionView::RecordIdentifier.dom_id(account_import),
        partial: "account_imports/account_import",
        locals: { account_import: }
      )
    end
end
