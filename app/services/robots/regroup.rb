module Robots
  # Reassigns every trade of an account to the robot its comment names today, and removes
  # robots left without trades. Run it after the grouping rule changes.
  class Regroup
    def initialize(account)
      @account = account
    end

    def call
      Account.transaction do
        @account.lock!
        robots = Robot.where(account: @account).index_by(&:key)

        @account.trades.distinct.pluck(:comment).each do |comment|
          key = Robot.key_for(comment)
          robot = key && (robots[key] ||= Robot.create!(account: @account, key:, name: Robot.name_for(comment)))
          @account.trades.where(comment:).update_all(robot_id: robot&.id, updated_at: Time.current)
        end

        Robot.where(account: @account).where.missing(:trades).delete_all
      end
    end
  end
end
