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
end
