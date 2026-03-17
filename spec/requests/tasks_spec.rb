require 'rails_helper'

RSpec.describe "Tasks API", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  describe "GET /tasks" do
    let!(:tasks) { create_list(:task, 3, user: user) }

    it "returns all tasks for the authenticated user" do
      get "/tasks", headers: headers
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["tasks"].size).to eq(3)
    end

    it "returns 401 without authentication" do
      get "/tasks"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /tasks/:id" do
    let!(:task) { create(:task, user: user) }

    it "returns a single task" do
      get "/tasks/#{task.id}", headers: headers
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["task"]["id"]).to eq(task.id)
    end

    it "returns 404 for non-existent task" do
      get "/tasks/99999", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /tasks" do
    let(:valid_params) do
      {
        task: {
          title: "New Task",
          status: "pending",
          priority: 1,
          due_date: Date.today + 7
        }
      }
    end

    it "creates a task" do
      expect {
        post "/tasks", params: valid_params, headers: headers
      }.to change(Task, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["task"]["title"]).to eq("New Task")
    end

    it "returns 422 with invalid params" do
      post "/tasks", params: { task: { title: "" } }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)

      json = JSON.parse(response.body)
      expect(json["errors"]).to be_present
    end
  end

  describe "PATCH /tasks/:id" do
    let!(:task) { create(:task, title: "Old Title", user: user) }

    it "updates the task" do
      patch "/tasks/#{task.id}", params: { task: { title: "Updated Title" } }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(task.reload.title).to eq("Updated Title")
    end

    it "returns 422 with invalid params" do
      patch "/tasks/#{task.id}", params: { task: { title: "" } }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 404 for another user's task" do
      other_user = create(:user)
      other_task = create(:task, user: other_user)

      patch "/tasks/#{other_task.id}", params: { task: { title: "Hacked" } }, headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /tasks/:id" do
    let!(:task) { create(:task, user: user) }

    it "deletes the task" do
      expect {
        delete "/tasks/#{task.id}", headers: headers
      }.to change(Task, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  # ========== PAGINATION ==========

  describe "Pagination" do
    before do
      create_list(:task, 30, user: user)
    end

    it "returns paginated results with default per_page" do
      get "/tasks", headers: headers

      json = JSON.parse(response.body)
      expect(json["tasks"].size).to be <= 25  # kaminari default
      expect(json["meta"]).to include("current_page", "total_pages", "total_count", "per_page")
    end

    it "returns the requested page" do
      get "/tasks", params: { page: 2, per_page: 10 }, headers: headers

      json = JSON.parse(response.body)
      expect(json["meta"]["current_page"]).to eq(2)
      expect(json["tasks"].size).to eq(10)
    end

    it "respects per_page parameter" do
      get "/tasks", params: { per_page: 5 }, headers: headers

      json = JSON.parse(response.body)
      expect(json["tasks"].size).to eq(5)
      expect(json["meta"]["per_page"]).to eq(5)
      expect(json["meta"]["total_count"]).to eq(30)
      expect(json["meta"]["total_pages"]).to eq(6)
    end

    it "returns empty array for page beyond total" do
      get "/tasks", params: { page: 100, per_page: 10 }, headers: headers

      json = JSON.parse(response.body)
      expect(json["tasks"]).to eq([])
    end
  end

  # ========== FILTERING ==========

  describe "Filtering" do
    let!(:todo_task) { create(:task, :todo, title: "Todo Task", priority: 1, user: user) }
    let!(:in_progress_task) { create(:task, :in_progress, title: "In Progress Task", priority: 2, user: user) }
    let!(:completed_task) { create(:task, :completed, title: "Completed Task", priority: 3, user: user) }

    describe "by status" do
      it "filters tasks by status" do
        get "/tasks", params: { status: "todo" }, headers: headers

        json = JSON.parse(response.body)
        statuses = json["tasks"].map { |t| t["status"] }
        expect(statuses).to all(eq("todo"))
        expect(json["tasks"].size).to eq(1)
      end

      it "returns empty when no tasks match status" do
        get "/tasks", params: { status: "archived" }, headers: headers

        json = JSON.parse(response.body)
        expect(json["tasks"]).to be_empty
      end
    end

    describe "by priority" do
      it "filters tasks by priority" do
        get "/tasks", params: { priority: 3 }, headers: headers

        json = JSON.parse(response.body)
        priorities = json["tasks"].map { |t| t["priority"] }
        expect(priorities).to all(eq(3))
        expect(json["tasks"].size).to eq(1)
      end
    end

    describe "by date range" do
      let!(:past_task) { create(:task, due_date: Date.today - 10, user: user) }
      let!(:future_task) { create(:task, due_date: Date.today + 30, user: user) }

      it "filters tasks due before a date" do
        get "/tasks", params: { due_before: Date.today }, headers: headers

        json = JSON.parse(response.body)
        json["tasks"].each do |task|
          expect(Date.parse(task["due_date"])).to be <= Date.today
        end
      end

      it "filters tasks due after a date" do
        get "/tasks", params: { due_after: Date.today + 20 }, headers: headers

        json = JSON.parse(response.body)
        json["tasks"].each do |task|
          expect(Date.parse(task["due_date"])).to be >= (Date.today + 20)
        end
      end
    end

    describe "combining filters" do
      it "combines status and priority filters" do
        get "/tasks", params: { status: "todo", priority: 1 }, headers: headers

        json = JSON.parse(response.body)
        expect(json["tasks"].size).to eq(1)
        expect(json["tasks"].first["status"]).to eq("todo")
        expect(json["tasks"].first["priority"]).to eq(1)
      end
    end
  end

  # ========== SEARCHING ==========

  describe "Searching" do
    let!(:task1) { create(:task, title: "Buy groceries", user: user) }
    let!(:task2) { create(:task, title: "Clean the house", user: user) }
    let!(:task3) { create(:task, title: "Buy new shoes", user: user) }

    it "searches tasks by title (case-insensitive)" do
      get "/tasks", params: { search: "buy" }, headers: headers

      json = JSON.parse(response.body)
      expect(json["tasks"].size).to eq(2)
      titles = json["tasks"].map { |t| t["title"] }
      expect(titles).to all(match(/buy/i))
    end

    it "returns empty when search has no matches" do
      get "/tasks", params: { search: "nonexistent" }, headers: headers

      json = JSON.parse(response.body)
      expect(json["tasks"]).to be_empty
    end

    it "combines search with filters" do
      task1.update!(status: "completed")

      get "/tasks", params: { search: "buy", status: "completed" }, headers: headers

      json = JSON.parse(response.body)
      expect(json["tasks"].size).to eq(1)
      expect(json["tasks"].first["title"]).to eq("Buy groceries")
    end
  end

  # ========== SORTING ==========

  describe "Sorting" do
    let!(:task_a) { create(:task, title: "A task", priority: 3, due_date: Date.today + 10, user: user) }
    let!(:task_b) { create(:task, title: "B task", priority: 1, due_date: Date.today + 1, user: user) }
    let!(:task_c) { create(:task, title: "C task", priority: 2, due_date: Date.today + 5, user: user) }

    it "sorts by created_at ascending (default)" do
      get "/tasks", params: { sort_by: "created_at", order: "asc" }, headers: headers

      json = JSON.parse(response.body)
      ids = json["tasks"].map { |t| t["id"] }
      expect(ids).to eq([task_a.id, task_b.id, task_c.id])
    end

    it "sorts by priority descending" do
      get "/tasks", params: { sort_by: "priority", order: "desc" }, headers: headers

      json = JSON.parse(response.body)
      priorities = json["tasks"].map { |t| t["priority"] }
      expect(priorities).to eq([3, 2, 1])
    end

    it "sorts by due_date ascending" do
      get "/tasks", params: { sort_by: "due_date", order: "asc" }, headers: headers

      json = JSON.parse(response.body)
      dates = json["tasks"].map { |t| t["due_date"] }
      expect(dates).to eq(dates.sort)
    end

    it "ignores invalid sort fields and defaults to created_at" do
      get "/tasks", params: { sort_by: "invalid_field", order: "asc" }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      ids = json["tasks"].map { |t| t["id"] }
      expect(ids).to eq([task_a.id, task_b.id, task_c.id])
    end

    it "ignores invalid sort direction and defaults to asc" do
      get "/tasks", params: { sort_by: "priority", order: "invalid" }, headers: headers

      json = JSON.parse(response.body)
      priorities = json["tasks"].map { |t| t["priority"] }
      expect(priorities).to eq([1, 2, 3])
    end
  end

  # ========== SERIALIZER ==========

  describe "Serializer" do
    let!(:task) { create(:task, user: user) }

    it "returns serialized task attributes" do
      get "/tasks/#{task.id}", headers: headers

      json = JSON.parse(response.body)
      task_json = json["task"]

      expect(task_json.keys).to contain_exactly(
        "id", "title", "description", "status", "priority", "due_date", "created_at", "updated_at"
      )
    end

    it "does not expose user_id in serialized output" do
      get "/tasks/#{task.id}", headers: headers

      json = JSON.parse(response.body)
      expect(json["task"]).not_to have_key("user_id")
    end
  end

  # ========== ERROR HANDLING ==========

  describe "Error handling" do
    it "returns 404 for non-existent task" do
      get "/tasks/99999", headers: headers

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:not_found)
      expect(json["error"]).to be_present
    end

    it "returns 422 for invalid task creation" do
      post "/tasks", params: { task: { title: "", status: "" } }, headers: headers

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["errors"]).to be_an(Array)
    end

    it "returns 401 for unauthenticated requests" do
      get "/tasks"

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:unauthorized)
      expect(json["error"]).to eq("Unauthorized")
    end
  end
end
