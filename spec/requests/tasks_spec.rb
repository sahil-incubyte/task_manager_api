RSpec.describe "Tasks API", type: :request do
  let(:user) { create(:user) }
  let(:token) { JsonWebToken.encode(user_id: user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }
  let!(:tasks) { create_list(:task, 3, user: user) }

  describe "GET /tasks" do
    it "returns all tasks for authenticated user" do
      get "/tasks", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['tasks'].size).to eq(3)
      expect(json['meta']).to be_present
    end

    it "requires authentication" do
      get "/tasks"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /tasks/:id" do
    let(:task) { create(:task, user: user) }

    it "returns a single task" do
      get "/tasks/#{task.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(task.id)
      expect(json).to have_key("user")
      expect(json).to have_key("overdue")
    end

    it "returns 404 for non-existent task" do
      get "/tasks/99999", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "requires authentication" do
      get "/tasks/#{task.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /tasks" do
    it "creates a task" do
      params = {
        task: {
          title: "New Task",
          description: "Task description",
          status: "todo",
          priority: "medium",
          due_date: Date.today + 1.day
        }
      }

      expect {
        post "/tasks", params: params, headers: headers
      }.to change(Task, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['title']).to eq("New Task")
      expect(json['user']['id']).to eq(user.id)
    end

    it "returns errors for invalid task" do
      params = {
        task: {
          description: "Missing title"
        }
      }

      expect {
        post "/tasks", params: params, headers: headers
      }.not_to change(Task, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json).to have_key('error')
      expect(json).to have_key('details')
    end

    it "requires authentication" do
      post "/tasks", params: { task: { title: "Test" } }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /tasks/:id" do
    let(:task) { create(:task, user: user, title: "Old Title") }

    it "updates the task" do
      patch "/tasks/#{task.id}", params: {
        task: { title: "Updated Title" }
      }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['title']).to eq("Updated Title")
      expect(task.reload.title).to eq("Updated Title")
    end

    it "returns errors for invalid update" do
      patch "/tasks/#{task.id}", params: {
        task: { title: "" }
      }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json).to have_key('error')
    end

    it "requires authentication" do
      patch "/tasks/#{task.id}", params: { task: { title: "Test" } }
      expect(response).to have_http_status(:unauthorized)
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

    it "returns 404 for non-existent task" do
      delete "/tasks/99999", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "requires authentication" do
      delete "/tasks/#{task.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
