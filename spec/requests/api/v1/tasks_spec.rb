require 'rails_helper'

RSpec.describe "API V1 Tasks", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  describe "GET /api/v1/tasks" do
    let!(:tasks) { create_list(:task, 3, user: user) }

    it "returns all tasks for the authenticated user" do
      get "/api/v1/tasks", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["tasks"].size).to eq(3)
    end

    it "returns 401 without authentication" do
      get "/api/v1/tasks"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/tasks/:id" do
    let!(:task) { create(:task, user: user) }

    it "returns a single task" do
      get "/api/v1/tasks/#{task.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["task"]["id"]).to eq(task.id)
    end
  end

  describe "POST /api/v1/tasks" do
    it "creates a task" do
      params = { task: { title: "V1 Task", status: "pending", priority: 1 } }

      expect {
        post "/api/v1/tasks", params: params, headers: headers
      }.to change(Task, :count).by(1)

      expect(response).to have_http_status(:created)
    end
  end

  describe "PATCH /api/v1/tasks/:id" do
    let!(:task) { create(:task, user: user) }

    it "updates the task" do
      patch "/api/v1/tasks/#{task.id}", params: { task: { title: "Updated" } }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(task.reload.title).to eq("Updated")
    end
  end

  describe "DELETE /api/v1/tasks/:id" do
    let!(:task) { create(:task, user: user) }

    it "deletes the task" do
      expect {
        delete "/api/v1/tasks/#{task.id}", headers: headers
      }.to change(Task, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "GET /api/v1/tasks/stats" do
    before do
      create(:task, :todo, user: user)
      create(:task, :completed, user: user)
    end

    it "returns task statistics" do
      get "/api/v1/tasks/stats", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["stats"]["total"]).to eq(2)
    end
  end

  describe "PATCH /api/v1/tasks/:id/complete" do
    let!(:task) { create(:task, :todo, user: user) }

    it "marks a task as completed" do
      patch "/api/v1/tasks/#{task.id}/complete", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["task"]["status"]).to eq("completed")
    end
  end
end
