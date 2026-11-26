# A deposit, withdrawal or other balance change that is not a trade.
class BalanceOperation < ApplicationRecord
  belongs_to :account

  validates :ticket, :executed_at, :kind, presence: true
  validates :amount, numericality: true
end
