# Idempotent: safe to run any number of times.

# The owner is created only when missing, so reseeding never resets a password.
if User.owners.none?
  if ENV["OWNER_PASSWORD"].present?
    OwnerAccount.new(email: ENV.fetch("OWNER_EMAIL", "owner@example.com"), password: ENV["OWNER_PASSWORD"]).call
  else
    puts "Skipped the owner account: set OWNER_PASSWORD (12+ characters) and run db:seed again."
  end
end

# The synthetic account shown in the public demo.
demo = Demo::AccountGenerator.new.call
puts "Demo account ready: #{demo.trades.count} synthetic trades."
