require "rails_helper"

RSpec.describe "Authentication" do
  it "sends signed-out visitors to the sign-in page" do
    get root_path

    expect(response).to redirect_to(new_session_path)
  end

  it "signs the owner in and out" do
    sign_in
    get root_path
    expect(response).to have_http_status(:ok)

    delete session_path
    get root_path
    expect(response).to redirect_to(new_session_path)
  end

  it "rejects a wrong password" do
    user = create(:user)

    post session_path, params: { email_address: user.email_address, password: "wrong-password!" }

    expect(response).to redirect_to(new_session_path)
    expect(Session.count).to eq(0)
  end

  it "offers no way to sign up or reset a password over the web" do
    paths = Rails.application.routes.routes.map { |route| route.path.spec.to_s }

    expect(paths.grep(/password|registration|sign_?up|users/)).to be_empty
  end

  describe "Sidekiq dashboard" do
    it "is not routable when signed out" do
      get "/sidekiq"

      expect(response).to have_http_status(:not_found)
    end

    it "is not routable for the demo user" do
      sign_in create(:user, :demo)

      get "/sidekiq"

      expect(response).to have_http_status(:not_found)
    end

    it "is available to the owner" do
      sign_in

      get "/sidekiq"

      expect(response).to have_http_status(:ok)
    end
  end
end
