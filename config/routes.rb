require "sidekiq/web"

Sidekiq::Web.use Rack::Auth::Basic do |username, password|
  ActiveSupport::SecurityUtils.secure_compare(username, ENV.fetch("SIDEKIQ_USERNAME", "admin")) &
  ActiveSupport::SecurityUtils.secure_compare(password, ENV.fetch("SIDEKIQ_PASSWORD", "password"))
end

Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
  get "health" => "health#show"

  mount Sidekiq::Web => "/sidekiq"

  # Authentication (non-RESTful, public endpoints)
  post 'signup', to: 'authentication#signup'
  post 'login', to: 'authentication#login'

  # Routing concern: reusable block for any resource that supports pagination/filtering
  concern :filterable do
    collection do
      get 'search'
    end
  end

  # Primary task routes with collection and member routes
  resources :tasks, concerns: :filterable do
    collection do
      get 'stats'
    end

    member do
      patch 'complete'
    end
  end

  # Nested routes: access tasks scoped to a specific user
  resources :users, only: [] do
    resources :tasks, only: [:index], controller: 'user_tasks'
  end

  # Singular resource: current user's profile (no :id needed)
  resource :profile, only: [:show, :update], controller: 'profiles'

  # API versioning with namespace
  namespace :api do
    namespace :v1 do
      resources :tasks, only: [:index, :show, :create, :update, :destroy] do
        collection do
          get 'stats'
        end

        member do
          patch 'complete'
        end
      end

      post 'signup', to: 'authentication#signup'
      post 'login', to: 'authentication#login'
      resource :profile, only: [:show, :update], controller: 'profiles'
    end
  end

  # Route constraints: only match numeric IDs
  constraints(id: /\d+/) do
    get 'tasks/:id/summary', to: 'tasks#show', as: :task_summary
  end

  # Scope: group routes under a path prefix without a module
  scope '/admin', as: 'admin' do
    get 'stats', to: 'tasks#stats', as: :stats
  end
end
