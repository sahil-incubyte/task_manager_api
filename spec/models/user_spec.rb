# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User, type: :model do
  it "is valid with valid attributes" do
    user = User.new(
      name: "Sahil",
      email: "sahil@test.com",
      password_digest: "password"
    )
    expect(user).to be_valid
  end

  it "is invalid without name" do
    user = User.new(email: "test@test.com", password_digest: "password")
    expect(user).not_to be_valid
  end

  it "is invalid without email" do
    user = User.new(name: "Sahil", password_digest: "password")
    expect(user).not_to be_valid
  end

  it { should validate_presence_of(:name) }

  it { should validate_presence_of(:email) }

  it { should validate_uniqueness_of(:email) }

  it { should have_many(:tasks).dependent(:destroy) }
end
