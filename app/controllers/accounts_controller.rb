class AccountsController < ApplicationController
  def index
    @accounts = Account.visible_to(Current.user).order(:name)
  end

  def show
    @account = Account.visible_to(Current.user).find(params[:id])
    @filter = Metrics::Filter.from_params(@account, params)
    @dashboard = Metrics::Dashboard.new(@filter).call
    list_imports = Current.user.owner? && Rails.configuration.x.imports_enabled
    @imports = list_imports ? @account.account_imports.order(created_at: :desc).limit(10) : []
  end
end
