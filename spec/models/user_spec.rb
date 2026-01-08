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
end
