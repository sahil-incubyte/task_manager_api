require 'rails_helper'

RSpec.describe "Authentication Protection", type: :request do
  let!(:user) do
    User.create!(
      name: "Sahil",
      email: "sahil@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  let(:token) { JsonWebToken.encode(user_id: user.id) }

  describe "Protected endpoints" do
    it "returns unauthorized without token" do
      get "/tasks"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  it "allows access with valid token" do
    get "/tasks", headers: {
      "Authorization" => "Bearer #{token}"
    }

    expect(response).not_to have_http_status(:unauthorized)
  end
end
