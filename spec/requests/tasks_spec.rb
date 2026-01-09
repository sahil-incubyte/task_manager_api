RSpec.describe "Tasks API", type: :request do
  let(:user) { create(:user) }
  let!(:tasks) { create_list(:task, 3, user: user) }

  describe "GET /tasks" do
    it "returns all tasks" do
      get "/tasks"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(3)
    end
  end

  describe "GET /tasks/:id" do
    let(:task) { create(:task) }

    it "returns a single task" do
      get "/tasks/#{task.id}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(task.id)
    end
  end

  describe "POST /tasks" do
    let(:user) { create(:user) }

    it "creates a task" do
      params = {
        task: {
          title: "New Task",
          status: "pending",
          priority: 1,
          due_date: Date.today,
          user_id: user.id
        }
      }

      expect {
        post "/tasks", params: params
      }.to change(Task, :count).by(1)

      expect(response).to have_http_status(:created)
    end
  end
end
