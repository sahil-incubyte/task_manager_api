require "rails_helper"

RSpec.describe "Task Stats API", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  describe "GET /tasks/stats" do
    before do
      create(:task, :todo, user: user, due_date: Date.today - 1)
      create(:task, :todo, user: user, due_date: Date.today)
      create(:task, :in_progress, user: user, priority: 2)
      create(:task, :completed, user: user, priority: 3)
    end

    it "returns task statistics" do
      get "/tasks/stats", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      stats = json["stats"]

      expect(stats["total"]).to eq(4)
      expect(stats["by_status"]).to include("todo" => 2, "in_progress" => 1, "completed" => 1)
      expect(stats["overdue"]).to eq(1)
      expect(stats["due_today"]).to eq(1)
    end

    it "returns 401 without authentication" do
      get "/tasks/stats"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /tasks/:id/complete" do
    let!(:task) { create(:task, :todo, user: user) }

    it "marks a task as completed" do
      patch "/tasks/#{task.id}/complete", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["task"]["status"]).to eq("completed")
      expect(task.reload.status).to eq("completed")
    end

    it "returns 404 for another user's task" do
      other_user = create(:user)
      other_task = create(:task, user: other_user)

      patch "/tasks/#{other_task.id}/complete", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /tasks/search" do
    before do
      create(:task, title: "Buy groceries", user: user)
      create(:task, title: "Buy shoes", user: user)
      create(:task, title: "Clean house", user: user)
    end

    it "searches tasks by query" do
      get "/tasks/search", params: { q: "buy" }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["tasks"].size).to eq(2)
    end

    it "returns empty results for no matches" do
      get "/tasks/search", params: { q: "nonexistent" }, headers: headers

      json = JSON.parse(response.body)
      expect(json["tasks"]).to be_empty
    end
  end
end
