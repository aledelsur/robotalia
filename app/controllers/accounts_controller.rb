class AccountsController < ApplicationController
  def index
    @accounts = Account.visible_to(Current.user).order(:name)
  end

  def show
    @account = Account.visible_to(Current.user).find(params[:id])
    @imports = Current.user.owner? ? @account.account_imports.order(created_at: :desc).limit(10) : []
  end
end
