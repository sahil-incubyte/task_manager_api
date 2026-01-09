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
end
