require 'rails_helper'

RSpec.describe "Tasks Sorting", type: :request do
  let(:user) { create(:user) }
  let(:token) { JsonWebToken.encode(user_id: user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe "GET /tasks - Sorting" do
    before do
      # Create tasks with different attributes for sorting
      @task1 = create(:task, user: user, title: "Alpha Task",
                      priority: 'high', due_date: Date.today + 5.days,
                      created_at: 3.days.ago)
      @task2 = create(:task, user: user, title: "Beta Task",
                      priority: 'low', due_date: Date.today + 1.day,
                      created_at: 2.days.ago)
      @task3 = create(:task, user: user, title: "Gamma Task",
                      priority: 'medium', due_date: Date.today + 3.days,
                      created_at: 1.day.ago)
    end

    it "sorts by created_at in descending order by default" do
      get "/tasks", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      titles = json['tasks'].map { |t| t['title'] }
      expect(titles).to eq([ 'Gamma Task', 'Beta Task', 'Alpha Task' ])
    end

    it "sorts by created_at in ascending order" do
      get "/tasks", params: { sort_by: 'created_at', order: 'asc' }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      titles = json['tasks'].map { |t| t['title'] }
      expect(titles).to eq([ 'Alpha Task', 'Beta Task', 'Gamma Task' ])
    end

    it "sorts by title in ascending order" do
      get "/tasks", params: { sort_by: 'title', order: 'asc' }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      titles = json['tasks'].map { |t| t['title'] }
      expect(titles).to eq([ 'Alpha Task', 'Beta Task', 'Gamma Task' ])
    end

    it "sorts by title in descending order" do
      get "/tasks", params: { sort_by: 'title', order: 'desc' }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      titles = json['tasks'].map { |t| t['title'] }
      expect(titles).to eq([ 'Gamma Task', 'Beta Task', 'Alpha Task' ])
    end

    it "sorts by due_date in ascending order" do
      get "/tasks", params: { sort_by: 'due_date', order: 'asc' }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      titles = json['tasks'].map { |t| t['title'] }
      expect(titles).to eq([ 'Beta Task', 'Gamma Task', 'Alpha Task' ])
    end

    it "sorts by due_date in descending order" do
      get "/tasks", params: { sort_by: 'due_date', order: 'desc' }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      titles = json['tasks'].map { |t| t['title'] }
      expect(titles).to eq([ 'Alpha Task', 'Gamma Task', 'Beta Task' ])
    end

    it "sorts by priority" do
      get "/tasks", params: { sort_by: 'priority', order: 'asc' }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      priorities = json['tasks'].map { |t| t['priority'] }
      expect(priorities.first).to eq('high')
      expect(priorities.last).to eq('low')
    end

    it "ignores invalid sort_by parameter and uses default" do
      get "/tasks", params: { sort_by: 'invalid_column' }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      # Should default to created_at desc
      titles = json['tasks'].map { |t| t['title'] }
      expect(titles).to eq([ 'Gamma Task', 'Beta Task', 'Alpha Task' ])
    end

    it "ignores invalid order parameter and uses default" do
      get "/tasks", params: { sort_by: 'title', order: 'invalid' }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      # Should default to desc
      titles = json['tasks'].map { |t| t['title'] }
      expect(titles).to eq([ 'Gamma Task', 'Beta Task', 'Alpha Task' ])
    end
  end

  describe "GET /tasks - Combined Sorting, Filtering, and Pagination" do
    before do
      create(:task, :high_priority, :todo, user: user, title: "High Priority Todo 1", created_at: 3.days.ago)
      create(:task, :high_priority, :todo, user: user, title: "High Priority Todo 2", created_at: 1.day.ago)
      create(:task, :high_priority, :completed, user: user, title: "High Priority Done", created_at: 2.days.ago)
      create(:task, :low_priority, :todo, user: user, title: "Low Priority Todo", created_at: 4.days.ago)
    end

    it "applies filtering, sorting, and pagination together" do
      get "/tasks", params: {
        status: 'todo',
        priority: 'high',
        sort_by: 'created_at',
        order: 'asc',
        per: 10
      }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['tasks'].size).to eq(2)
      expect(json['tasks'].all? { |t| t['status'] == 'todo' && t['priority'] == 'high' }).to be true

      titles = json['tasks'].map { |t| t['title'] }
      expect(titles).to eq([ 'High Priority Todo 1', 'High Priority Todo 2' ])

      expect(json['meta']['total_count']).to eq(2)
    end

    it "searches, sorts, and paginates together" do
      get "/tasks", params: {
        search: 'High',
        sort_by: 'title',
        order: 'asc',
        per: 2
      }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['tasks'].size).to eq(2)
      titles = json['tasks'].map { |t| t['title'] }
      expect(titles.first).to eq('High Priority Done')
    end
  end
end
