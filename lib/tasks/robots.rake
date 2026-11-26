namespace :robots do
  desc "Regroup every account's trades by the robot named in their comments"
  task regroup: :environment do
    Account.find_each do |account|
      Robots::Regroup.new(account).call
      puts "#{account.name}: #{account.robots.count} robots"
    end
  end
end
