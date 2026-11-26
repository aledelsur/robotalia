require "rails_helper"

RSpec.describe "Accounts" do
  let!(:real) { create(:account, name: "Real one") }
  let!(:demo) { create(:account, name: "Demo one", demo: true) }

  it "shows the owner every account" do
    sign_in
    get root_path

    expect(response.body).to include("Real one", "Demo one")
  end

  it "shows the demo user demo accounts only" do
    sign_in create(:user, :demo)
    get root_path
    expect(response.body).to include("Demo one")
    expect(response.body).not_to include("Real one", "Import report", "/sidekiq")

    get account_path(real)
    expect(response).to have_http_status(:not_found)
  end
end
