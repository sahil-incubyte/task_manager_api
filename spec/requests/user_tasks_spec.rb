require 'rails_helper'

RSpec.describe "User Tasks API (nested routes)", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  describe "GET /users/:user_id/tasks" do
    let!(:tasks) { create_list(:task, 3, user: user) }

    it "returns tasks for the specified user" do
      get "/users/#{user.id}/tasks", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["tasks"].size).to eq(3)
    end

    it "returns 403 when accessing another user's tasks" do
      other_user = create(:user)

      get "/users/#{other_user.id}/tasks", headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 401 without authentication" do
      get "/users/#{user.id}/tasks"
      expect(response).to have_http_status(:unauthorized)
    end

    it "supports filtering by status" do
      create(:task, :completed, user: user)

      get "/users/#{user.id}/tasks", params: { status: "completed" }, headers: headers

      json = JSON.parse(response.body)
      statuses = json["tasks"].map { |t| t["status"] }
      expect(statuses).to all(eq("completed"))
    end

    it "supports pagination" do
      create_list(:task, 10, user: user)

      get "/users/#{user.id}/tasks", params: { per_page: 5 }, headers: headers

      json = JSON.parse(response.body)
      expect(json["tasks"].size).to eq(5)
      expect(json["meta"]["total_count"]).to eq(13)
    end
  end
end
