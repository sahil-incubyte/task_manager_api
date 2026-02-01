require 'rails_helper'

RSpec.describe "Tasks Pagination and Filtering", type: :request do
  let(:user) { create(:user) }
  let(:token) { JsonWebToken.encode(user_id: user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe "GET /tasks - Pagination" do
    before do
      create_list(:task, 25, user: user)
    end

    it "returns paginated tasks with default settings" do
      get "/tasks", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['tasks'].size).to eq(10) # Default per_page
      expect(json['meta']['current_page']).to eq(1)
      expect(json['meta']['total_pages']).to eq(3)
      expect(json['meta']['total_count']).to eq(25)
      expect(json['meta']['per_page']).to eq(10)
    end

    it "returns specified page with custom per_page" do
      get "/tasks", params: { page: 2, per: 5 }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['tasks'].size).to eq(5)
      expect(json['meta']['current_page']).to eq(2)
      expect(json['meta']['total_pages']).to eq(5)
      expect(json['meta']['per_page']).to eq(5)
    end

    it "returns last page correctly" do
      get "/tasks", params: { page: 3, per: 10 }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['tasks'].size).to eq(5) # Last page has 5 items
      expect(json['meta']['current_page']).to eq(3)
      expect(json['meta']['next_page']).to be_nil
    end

    it "limits maximum per_page to 100" do
      get "/tasks", params: { per: 200 }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['meta']['per_page']).to eq(100)
    end
  end

  describe "GET /tasks - Filtering by Status" do
    before do
      create(:task, :todo, user: user, title: "Todo task 1")
      create(:task, :todo, user: user, title: "Todo task 2")
      create(:task, :in_progress, user: user, title: "In progress task")
      create(:task, :completed, user: user, title: "Completed task")
    end

    it "filters tasks by todo status" do
      get "/tasks", params: { status: 'todo' }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['tasks'].size).to eq(2)
      expect(json['tasks'].all? { |t| t['status'] == 'todo' }).to be true
    end

    it "filters tasks by in_progress status" do
      get "/tasks", params: { status: 'in_progress' }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['tasks'].size).to eq(1)
      expect(json['tasks'].first['status']).to eq('in_progress')
    end

    it "filters tasks by completed status" do
      get "/tasks", params: { status: 'completed' }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['tasks'].size).to eq(1)
      expect(json['tasks'].first['status']).to eq('completed')
    end
  end

  describe "GET /tasks - Filtering by Priority" do
    before do
      create(:task, :low_priority, user: user, title: "Low priority task")
      create(:task, :medium_priority, user: user, title: "Medium priority 1")
      create(:task, :medium_priority, user: user, title: "Medium priority 2")
      create(:task, :high_priority, user: user, title: "High priority task")
    end

    it "filters tasks by low priority" do
      get "/tasks", params: { priority: 'low' }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['tasks'].size).to eq(1)
      expect(json['tasks'].first['priority']).to eq('low')
    end

    it "filters tasks by medium priority" do
      get "/tasks", params: { priority: 'medium' }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['tasks'].size).to eq(2)
      expect(json['tasks'].all? { |t| t['priority'] == 'medium' }).to be true
    end

    it "filters tasks by high priority" do
      get "/tasks", params: { priority: 'high' }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['tasks'].size).to eq(1)
      expect(json['tasks'].first['priority']).to eq('high')
    end
  end

  describe "GET /tasks - Combining Filters" do
    before do
      create(:task, :todo, :high_priority, user: user, title: "Todo high")
      create(:task, :todo, :low_priority, user: user, title: "Todo low")
      create(:task, :in_progress, :high_priority, user: user, title: "In progress high")
      create(:task, :completed, :high_priority, user: user, title: "Completed high")
    end

    it "filters by both status and priority" do
      get "/tasks", params: { status: 'todo', priority: 'high' }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['tasks'].size).to eq(1)
      expect(json['tasks'].first['title']).to eq('Todo high')
      expect(json['tasks'].first['status']).to eq('todo')
      expect(json['tasks'].first['priority']).to eq('high')
    end
  end

  describe "GET /tasks - Searching by Title" do
    before do
      create(:task, user: user, title: "Buy groceries")
      create(:task, user: user, title: "Buy birthday gift")
      create(:task, user: user, title: "Schedule meeting")
      create(:task, user: user, title: "Complete report")
    end

    it "searches tasks by title (case insensitive)" do
      get "/tasks", params: { search: 'buy' }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['tasks'].size).to eq(2)
      titles = json['tasks'].map { |t| t['title'] }
      expect(titles).to include('Buy groceries', 'Buy birthday gift')
    end

    it "searches with partial match" do
      get "/tasks", params: { search: 'meet' }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['tasks'].size).to eq(1)
      expect(json['tasks'].first['title']).to eq('Schedule meeting')
    end

    it "returns empty array when no matches found" do
      get "/tasks", params: { search: 'nonexistent' }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['tasks'].size).to eq(0)
    end
  end

  describe "GET /tasks - Date Range Filtering" do
    before do
      create(:task, user: user, title: "Task 1", due_date: Date.today - 5.days)
      create(:task, user: user, title: "Task 2", due_date: Date.today)
      create(:task, user: user, title: "Task 3", due_date: Date.today + 3.days)
      create(:task, user: user, title: "Task 4", due_date: Date.today + 10.days)
    end

    it "filters tasks by date range" do
      start_date = Date.today - 1.day
      end_date = Date.today + 5.days

      get "/tasks", params: { start_date: start_date, end_date: end_date }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['tasks'].size).to eq(2)
      titles = json['tasks'].map { |t| t['title'] }
      expect(titles).to include('Task 2', 'Task 3')
    end
  end
end
