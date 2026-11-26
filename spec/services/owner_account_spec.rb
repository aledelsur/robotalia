require "rails_helper"

RSpec.describe OwnerAccount do
  subject(:set_owner) { described_class.new(email: "new@example.com", password: "a-brand-new-password").call }

  it "creates the owner" do
    expect { set_owner }.to change(User, :count).from(0).to(1)
  end

  it "leaves the demo user alone" do
    demo = create(:user, :demo)

    expect { set_owner }.to change(User.owners, :count).from(0).to(1)
    expect(demo.reload.email_address).to eq("demo@example.com")
  end

  it "updates the existing owner and signs out their sessions" do
    owner = create(:user)
    owner.sessions.create!

    expect { set_owner }.not_to change(User, :count)
    expect(owner.reload.email_address).to eq("new@example.com")
    expect(owner.authenticate("a-brand-new-password")).to be_truthy
    expect(owner.sessions).to be_empty
  end
end
