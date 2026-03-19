require 'rails_helper'

RSpec.configure do |config|
  config.openapi_root = Rails.root.join('swagger').to_s
  config.rswag_dry_run = false

  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'Task Manager API',
        version: 'v1',
        description: 'RESTful API for managing tasks with JWT authentication'
      },
      paths: {},
      servers: [
        { url: 'http://localhost:3000', description: 'Development server' }
      ],
      components: {
        securitySchemes: {
          Bearer: {
            type: :apiKey,
            name: 'Authorization',
            in: :header,
            description: 'Enter: Bearer <your_jwt_token>'
          }
        },
        schemas: {
          Task: {
            type: :object,
            properties: {
              id: { type: :integer },
              title: { type: :string },
              description: { type: :string, nullable: true },
              status: { type: :string, enum: %w[todo in_progress completed pending] },
              priority: { type: :integer, nullable: true },
              due_date: { type: :string, format: :date, nullable: true },
              created_at: { type: :string, format: :'date-time' },
              updated_at: { type: :string, format: :'date-time' }
            },
            required: %w[id title status created_at updated_at]
          },
          PaginationMeta: {
            type: :object,
            properties: {
              current_page: { type: :integer },
              total_pages: { type: :integer },
              total_count: { type: :integer },
              per_page: { type: :integer }
            }
          },
          ErrorResponse: {
            type: :object,
            properties: {
              error: { type: :string }
            }
          },
          ValidationErrorResponse: {
            type: :object,
            properties: {
              errors: {
                type: :array,
                items: { type: :string }
              }
            }
          }
        }
      }
    }
  }

  config.openapi_format = :yaml
end
