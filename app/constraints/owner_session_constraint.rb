# Route constraint for mounted Rack apps, which don't run ApplicationController's
# authentication. It checks the same signed session cookie.
class OwnerSessionConstraint
  def matches?(request)
    Session.find_by_signed_cookie(request.cookie_jar)&.user&.owner? || false
  end
end
