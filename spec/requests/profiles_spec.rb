require 'rails_helper'

RSpec.describe "Profiles API", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  describe "GET /profile" do
    it "returns the current user's profile" do
      create_list(:task, 3, user: user)

      get "/profile", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["profile"]["id"]).to eq(user.id)
      expect(json["profile"]["name"]).to eq(user.name)
      expect(json["profile"]["email"]).to eq(user.email)
      expect(json["profile"]["task_count"]).to eq(3)
    end

    it "returns 401 without authentication" do
      get "/profile"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /profile" do
    it "updates the current user's profile" do
      patch "/profile", params: { profile: { name: "Updated Name" } }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["profile"]["name"]).to eq("Updated Name")
      expect(user.reload.name).to eq("Updated Name")
    end

    it "returns 422 with invalid params" do
      patch "/profile", params: { profile: { name: "" } }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
