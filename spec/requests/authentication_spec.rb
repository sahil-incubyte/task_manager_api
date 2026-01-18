require 'rails_helper'

RSpec.describe "Authentication API", type: :request do
  describe "POST /signup" do
    let(:valid_params) do
      {
        name: "Sahil",
        email: "sahil@test.com",
        password: "password123",
        password_confirmation: "password123"
      }
    end

    it "creates a user and returns a JWT token" do
      post "/signup", params: valid_params

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)).to have_key("token")
      expect(User.count).to eq(1)
    end

    it "returns errors for invalid signup" do
      post "/signup", params: { email: "" }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /login" do
    let!(:user) do
      User.create!(
        name: "Sahil",
        email: "sahil@test.com",
        password: "password123",
        password_confirmation: "password123"
      )
    end

    it "returns JWT token for valid credentials" do
      post "/login", params: { email: user.email, password: "password123" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to have_key("token")
    end

    it "returns unauthorized for invalid credentials" do
      post "/login", params: { email: user.email, password: "wrongpass" }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
