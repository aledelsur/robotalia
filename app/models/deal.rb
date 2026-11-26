# One executed deal, as listed in the MT5 report.
class Deal < ApplicationRecord
  belongs_to :account

  validates :ticket, :executed_at, :symbol, :volume, :price, presence: true
  validates :side, inclusion: { in: %w[buy sell] }
  validates :direction, inclusion: { in: [ "in", "out", "in/out", "out by" ] }
end
