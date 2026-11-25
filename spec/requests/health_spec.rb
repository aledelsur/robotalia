require "rails_helper"

RSpec.describe "Health check" do
  it "reports that the app has booted, for compose and deploy healthchecks" do
    get "/up"

    expect(response).to have_http_status(:ok)
  end
end
