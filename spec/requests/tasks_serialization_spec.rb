require 'rails_helper'

RSpec.describe "Tasks Serialization and Error Handling", type: :request do
  let(:user) { create(:user) }
  let(:token) { JsonWebToken.encode(user_id: user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe "Task Serialization" do
    let!(:task) { create(:task, user: user, due_date: Date.today + 1.day) }

    it "includes all required attributes in task response" do
      get "/tasks/#{task.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json).to have_key('id')
      expect(json).to have_key('title')
      expect(json).to have_key('description')
      expect(json).to have_key('status')
      expect(json).to have_key('priority')
      expect(json).to have_key('due_date')
      expect(json).to have_key('created_at')
      expect(json).to have_key('updated_at')
      expect(json).to have_key('user')
      expect(json).to have_key('overdue')
    end

    it "includes user information in task response" do
      get "/tasks/#{task.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['user']).to have_key('id')
      expect(json['user']).to have_key('name')
      expect(json['user']).to have_key('email')
      expect(json['user']).not_to have_key('password_digest')
    end

    it "formats due_date correctly" do
      get "/tasks/#{task.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['due_date']).to match(/\d{4}-\d{2}-\d{2}/)
    end

    it "calculates overdue status correctly for future tasks" do
      future_task = create(:task, user: user, due_date: Date.today + 5.days, status: 'todo')

      get "/tasks/#{future_task.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['overdue']).to be false
    end

    it "calculates overdue status correctly for past incomplete tasks" do
      overdue_task = create(:task, user: user, due_date: Date.today - 1.day, status: 'todo')

      get "/tasks/#{overdue_task.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['overdue']).to be true
    end

    it "calculates overdue status correctly for past completed tasks" do
      completed_task = create(:task, user: user, due_date: Date.today - 1.day, status: 'completed')

      get "/tasks/#{completed_task.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['overdue']).to be false
    end

    it "uses serializer for create action" do
      post "/tasks", params: {
        task: {
          title: "New Task",
          description: "Description",
          status: "todo",
          priority: "high",
          due_date: Date.today + 2.days
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)

      expect(json).to have_key('user')
      expect(json).to have_key('overdue')
    end

    it "uses serializer for update action" do
      patch "/tasks/#{task.id}", params: {
        task: { title: "Updated Title" }
      }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json).to have_key('user')
      expect(json).to have_key('overdue')
      expect(json['title']).to eq('Updated Title')
    end
  end

  describe "Error Handling" do
    let!(:task) { create(:task, user: user) }
    let(:other_user) { create(:user, email: 'other@example.com') }
    let(:other_token) { JsonWebToken.encode(user_id: other_user.id) }
    let(:other_headers) { { 'Authorization' => "Bearer #{other_token}" } }

    context "Record Not Found" do
      it "returns 404 when task does not exist" do
        get "/tasks/99999", headers: headers

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)

        expect(json).to have_key('error')
        expect(json['error']).to eq('Record not found')
        expect(json).to have_key('message')
      end
    end

    context "Unauthorized Access" do
      it "returns 403 when trying to access another user's task" do
        get "/tasks/#{task.id}", headers: other_headers

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)

        expect(json).to have_key('error')
        expect(json['error']).to eq('Unauthorized access to this task')
      end

      it "returns 403 when trying to update another user's task" do
        patch "/tasks/#{task.id}", params: {
          task: { title: "Hacked Title" }
        }, headers: other_headers

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)

        expect(json).to have_key('error')
      end

      it "returns 403 when trying to delete another user's task" do
        delete "/tasks/#{task.id}", headers: other_headers

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)

        expect(json).to have_key('error')
      end
    end

    context "Validation Errors" do
      it "returns 422 when creating task without required fields" do
        post "/tasks", params: {
          task: {
            description: "No title"
          }
        }, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)

        expect(json).to have_key('error')
        expect(json['error']).to eq('Validation failed')
        expect(json).to have_key('details')
        expect(json['details']).to be_an(Array)
      end

      it "returns 422 when updating task with invalid data" do
        patch "/tasks/#{task.id}", params: {
          task: { title: "" }
        }, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)

        expect(json).to have_key('error')
        expect(json['error']).to eq('Validation failed')
        expect(json).to have_key('details')
      end

      it "returns 422 when creating task with invalid status" do
        post "/tasks", params: {
          task: {
            title: "Test",
            status: "invalid_status",
            priority: "low"
          }
        }, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)

        expect(json).to have_key('error')
      end

      it "returns 422 when creating task with invalid priority" do
        post "/tasks", params: {
          task: {
            title: "Test",
            status: "todo",
            priority: "invalid_priority"
          }
        }, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)

        expect(json).to have_key('error')
      end
    end

    context "Authentication Errors" do
      it "returns 401 when no token provided" do
        get "/tasks"

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)

        expect(json).to have_key('error')
      end

      it "returns 401 when invalid token provided" do
        invalid_headers = { 'Authorization' => 'Bearer invalid_token' }
        get "/tasks", headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)

        expect(json).to have_key('error')
      end
    end
  end

  describe "HTTP Status Codes" do
    let!(:task) { create(:task, user: user) }

    it "returns 200 OK for successful GET requests" do
      get "/tasks", headers: headers
      expect(response).to have_http_status(:ok)

      get "/tasks/#{task.id}", headers: headers
      expect(response).to have_http_status(:ok)
    end

    it "returns 201 Created for successful POST requests" do
      post "/tasks", params: {
        task: {
          title: "New Task",
          status: "todo",
          priority: "medium"
        }
      }, headers: headers

      expect(response).to have_http_status(:created)
    end

    it "returns 200 OK for successful PATCH requests" do
      patch "/tasks/#{task.id}", params: {
        task: { title: "Updated" }
      }, headers: headers

      expect(response).to have_http_status(:ok)
    end

    it "returns 204 No Content for successful DELETE requests" do
      delete "/tasks/#{task.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
    end
  end

  describe "Consistent Error Format" do
    it "returns errors in consistent format across endpoints" do
      # Test validation error format
      post "/tasks", params: { task: { description: "No title" } }, headers: headers
      validation_error = JSON.parse(response.body)
      expect(validation_error).to have_key('error')
      expect(validation_error).to have_key('details')

      # Test not found error format
      get "/tasks/99999", headers: headers
      not_found_error = JSON.parse(response.body)
      expect(not_found_error).to have_key('error')
      expect(not_found_error).to have_key('message')

      # Test unauthorized error format
      get "/tasks"
      auth_error = JSON.parse(response.body)
      expect(auth_error).to have_key('error')
    end
  end
end
