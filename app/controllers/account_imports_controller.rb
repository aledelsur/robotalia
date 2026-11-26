class AccountImportsController < ApplicationController
  include OwnerOnly

  before_action :require_imports_enabled

  def new
    @account_import = AccountImport.new
  end

  def create
    @account_import = AccountImport.new
    report = params.dig(:account_import, :report)
    # Only a real upload is attached, never a signed id or other string from the request.
    @account_import.report.attach(report) if report.respond_to?(:original_filename)

    if @account_import.save
      ImportAccountReportJob.perform_later(@account_import)
      redirect_to @account_import, status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    @account_import = AccountImport.find(params[:id])
  end

  private
    def require_imports_enabled
      redirect_to root_path, alert: "Imports are disabled on this server." unless Rails.configuration.x.imports_enabled
    end
end
