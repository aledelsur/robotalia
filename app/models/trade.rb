# One closed position. Metrics are computed from trades.
class Trade < ApplicationRecord
  belongs_to :account
  belongs_to :robot, optional: true

  validates :position_id, :symbol, :opened_at, :closed_at, :open_price, :close_price, presence: true
  validates :side, inclusion: { in: %w[buy sell] }
  validates :volume, numericality: { greater_than: 0 }
  validate :closes_after_it_opens

  before_validation :compute_net_profit

  private
    def compute_net_profit
      self.net_profit = [ profit, commission, swap ].sum(&:to_d)
    end

    def closes_after_it_opens
      errors.add(:closed_at, "is before the open time") if opened_at && closed_at && closed_at < opened_at
    end
end
