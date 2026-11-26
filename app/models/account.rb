class Account < ApplicationRecord
  has_many :account_imports, dependent: :destroy
  has_many :trades, dependent: :delete_all
  has_many :deals, dependent: :delete_all
  has_many :balance_operations, dependent: :delete_all
  # Declared after trades, which reference robots.
  has_many :robots, dependent: :delete_all

  validates :name, :login, presence: true
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validates :initial_balance, numericality: true

  def masked_login
    "••••#{login.last(4)}"
  end
end
