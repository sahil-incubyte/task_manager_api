require 'swagger_helper'

RSpec.describe 'Tasks', type: :request do
  let(:user) do
    User.create!(
      name: 'Task User',
      email: 'taskuser@test.com',
      password: 'password123',
      password_confirmation: 'password123'
    )
  end

  let(:Authorization) { "Bearer #{JsonWebToken.encode(user_id: user.id)}" }

  path '/tasks' do
    get 'List tasks with pagination, filtering, searching, and sorting' do
      tags 'Tasks'
      produces 'application/json'
      security [Bearer: []]

      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Items per page'
      parameter name: :status, in: :query, type: :string, required: false,
                enum: %w[todo in_progress completed pending], description: 'Filter by status'
      parameter name: :priority, in: :query, type: :integer, required: false,
                enum: [1, 2, 3], description: 'Filter by priority'
      parameter name: :search, in: :query, type: :string, required: false, description: 'Search tasks by title'
      parameter name: :sort_by, in: :query, type: :string, required: false,
                enum: %w[created_at due_date priority], description: 'Sort field'
      parameter name: :order, in: :query, type: :string, required: false,
                enum: %w[asc desc], description: 'Sort direction'
      parameter name: :due_before, in: :query, type: :string, format: :date, required: false,
                description: 'Filter tasks due on or before date'
      parameter name: :due_after, in: :query, type: :string, format: :date, required: false,
                description: 'Filter tasks due on or after date'

      response '200', 'tasks listed' do
        let!(:task) { Task.create!(title: 'Sample Task', status: 'todo', priority: 1, user: user) }

        schema type: :object, properties: {
          tasks: { type: :array, items: { '$ref' => '#/components/schemas/Task' } },
          meta: { '$ref' => '#/components/schemas/PaginationMeta' }
        }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['tasks']).to be_an(Array)
          expect(data['meta']).to be_a(Hash)
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid_token' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a new task' do
      tags 'Tasks'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          task: {
            type: :object,
            properties: {
              title: { type: :string },
              description: { type: :string },
              status: { type: :string, enum: %w[todo in_progress completed pending] },
              priority: { type: :integer },
              due_date: { type: :string, format: :date }
            },
            required: %w[title status]
          }
        },
        required: ['task']
      }

      response '201', 'task created' do
        let(:body) { { task: { title: 'New Task', status: 'todo', priority: 1 } } }

        schema type: :object, properties: {
          task: { '$ref' => '#/components/schemas/Task' }
        }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['task']['title']).to eq('New Task')
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid_token' }
        let(:body) { { task: { title: 'New Task', status: 'todo' } } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '422', 'validation errors' do
        let(:body) { { task: { title: '', status: '' } } }

        schema '$ref' => '#/components/schemas/ValidationErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['errors']).to be_an(Array)
        end
      end
    end
  end

  path '/tasks/{id}' do
    let!(:existing_task) { Task.create!(title: 'Existing Task', status: 'todo', priority: 1, user: user) }

    get 'Get a specific task' do
      tags 'Tasks'
      produces 'application/json'
      security [Bearer: []]

      parameter name: :id, in: :path, type: :integer, required: true, description: 'Task ID'

      response '200', 'task found' do
        let(:id) { existing_task.id }

        schema type: :object, properties: {
          task: { '$ref' => '#/components/schemas/Task' }
        }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['task']['id']).to eq(existing_task.id)
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid_token' }
        let(:id) { existing_task.id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '404', 'task not found' do
        let(:id) { 0 }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a task' do
      tags 'Tasks'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]

      parameter name: :id, in: :path, type: :integer, required: true, description: 'Task ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          task: {
            type: :object,
            properties: {
              title: { type: :string },
              description: { type: :string },
              status: { type: :string, enum: %w[todo in_progress completed pending] },
              priority: { type: :integer },
              due_date: { type: :string, format: :date }
            }
          }
        },
        required: ['task']
      }

      response '200', 'task updated' do
        let(:id) { existing_task.id }
        let(:body) { { task: { title: 'Updated Task' } } }

        schema type: :object, properties: {
          task: { '$ref' => '#/components/schemas/Task' }
        }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['task']['title']).to eq('Updated Task')
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid_token' }
        let(:id) { existing_task.id }
        let(:body) { { task: { title: 'Updated' } } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '404', 'task not found' do
        let(:id) { 0 }
        let(:body) { { task: { title: 'Updated' } } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '422', 'validation errors' do
        let(:id) { existing_task.id }
        let(:body) { { task: { title: '' } } }

        schema '$ref' => '#/components/schemas/ValidationErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['errors']).to be_an(Array)
        end
      end
    end

    delete 'Delete a task' do
      tags 'Tasks'
      security [Bearer: []]

      parameter name: :id, in: :path, type: :integer, required: true, description: 'Task ID'

      response '204', 'task deleted' do
        let(:id) { existing_task.id }

        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid_token' }
        let(:id) { existing_task.id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '404', 'task not found' do
        let(:id) { 0 }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
