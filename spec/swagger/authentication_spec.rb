require 'swagger_helper'

RSpec.describe 'Authentication', type: :request do
  path '/signup' do
    post 'Register a new user' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          email: { type: :string },
          password: { type: :string },
          password_confirmation: { type: :string }
        },
        required: %w[name email password password_confirmation]
      }

      response '201', 'user registered' do
        let(:body) do
          {
            name: 'Test User',
            email: 'signup@test.com',
            password: 'password123',
            password_confirmation: 'password123'
          }
        end

        schema type: :object, properties: { token: { type: :string } }, required: ['token']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
        end
      end

      response '422', 'validation errors' do
        let(:body) { { name: '', email: '', password: '', password_confirmation: '' } }

        schema '$ref' => '#/components/schemas/ValidationErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['errors']).to be_an(Array)
        end
      end
    end
  end

  path '/login' do
    post 'Authenticate user' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string },
          password: { type: :string }
        },
        required: %w[email password]
      }

      response '200', 'authenticated' do
        let!(:user) do
          User.create!(
            name: 'Test User',
            email: 'login@test.com',
            password: 'password123',
            password_confirmation: 'password123'
          )
        end

        let(:body) { { email: 'login@test.com', password: 'password123' } }

        schema type: :object, properties: { token: { type: :string } }, required: ['token']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
        end
      end

      response '401', 'invalid credentials' do
        let(:body) { { email: 'nobody@test.com', password: 'wrongpass' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('Invalid email or password')
        end
      end
    end
  end
end
