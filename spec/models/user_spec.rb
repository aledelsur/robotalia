require "rails_helper"

RSpec.describe User do
  it "normalizes the email address" do
    expect(build(:user, email_address: "  Owner@Example.COM ").email_address).to eq("owner@example.com")
  end

  it "requires a password of at least 12 characters" do
    expect(build(:user, password: "short")).not_to be_valid
  end

  it "allows only one owner account" do
    create(:user)

    second = build(:user, email_address: "other@example.com")

    expect(second).not_to be_valid
    expect(second.errors[:base]).to include("Robotalia has a single owner account")
  end

  it "allows a demo user next to the owner, but only one" do
    create(:user)
    create(:user, :demo)

    expect(build(:user, :demo, email_address: "demo2@example.com")).not_to be_valid
  end

  it "keeps an existing account valid when it is updated" do
    expect(create(:user)).to be_valid
  end

  it "enforces the single owner in the database too" do
    create(:user)

    expect { build(:user, email_address: "other@example.com").save!(validate: false) }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end
end
