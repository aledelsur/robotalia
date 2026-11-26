namespace :owner do
  desc "Create the owner account or reset it from OWNER_EMAIL and OWNER_PASSWORD (signs out all sessions)"
  task set: :environment do
    owner = OwnerAccount.new(email: ENV.fetch("OWNER_EMAIL"), password: ENV.fetch("OWNER_PASSWORD")).call
    puts "Owner account ready: #{owner.email_address}"
  end
end
