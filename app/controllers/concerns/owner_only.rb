# The demo user is read-only.
module OwnerOnly
  extend ActiveSupport::Concern

  included do
    before_action :require_owner
  end

  private
    def require_owner
      redirect_to root_path, alert: "The demo account is read-only." unless Current.user.owner?
    end
end
