# A small hand-checkable account for metrics specs.
module MetricsHelpers
  def deposit(account, time, amount)
    @ticket = (@ticket || 0) + 1
    account.balance_operations.create!(ticket: @ticket, executed_at: Time.zone.parse(time), kind: "balance", amount:)
  end

  # net is the net profit: no commission or swap.
  def closed(account, time, net, **attributes)
    closed_at = Time.zone.parse(time)
    create(:trade, account:, opened_at: closed_at - 1.hour, closed_at:, profit: net, commission: 0, swap: 0, **attributes)
  end
end

RSpec.configure do |config|
  config.include MetricsHelpers
end
