# Creates the owner account, or updates its email and password.
class OwnerAccount
  def initialize(email:, password:)
    @email = email
    @password = password
  end

  def call
    owner = User.owners.first || User.new
    owner.update!(email_address: @email, password: @password)
    owner.sessions.destroy_all
    owner
  end
end
