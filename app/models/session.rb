class Session < ApplicationRecord
  belongs_to :user

  # The single definition of "who is signed in", shared by controllers,
  # route constraints, Action Cable and the admin.
  def self.find_by_signed_cookie(cookie_jar)
    id = cookie_jar.signed[:session_id]
    find_by(id: id) if id
  end
end
