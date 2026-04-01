require "rails_helper"

RSpec.describe "API V1 Authentication", type: :request do
  describe "POST /api/v1/signup" do
    it "creates a new user and returns a token" do
      params = { name: "Test User", email: "v1test@example.com", password: "password123", password_confirmation: "password123" }

      post "/api/v1/signup", params: params

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["token"]).to be_present
    end

    it "returns 422 with invalid params" do
      post "/api/v1/signup", params: { name: "", email: "" }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /api/v1/login" do
    let!(:user) { create(:user, email: "v1login@example.com", password: "password123") }

    it "returns a token with valid credentials" do
      post "/api/v1/login", params: { email: "v1login@example.com", password: "password123" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["token"]).to be_present
    end

    it "returns 401 with invalid credentials" do
      post "/api/v1/login", params: { email: "v1login@example.com", password: "wrong" }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
