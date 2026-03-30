## Context Summary

Analysis method: text-based pattern matching

### Project Structure
- **Stack**: Ruby on Rails 8.0 (API-only mode), Ruby, PostgreSQL
- **Build**: Bundler, Kamal for deployment, Docker
- **Layout**: Standard Rails directory structure (`app/controllers/`, `app/models/`, `app/services/`, `app/serializers/`, `spec/`)
- **Key dependencies**:
  - `pg` -- PostgreSQL adapter
  - `bcrypt` -- password hashing via `has_secure_password`
  - `jwt` (~> 2.8) -- JWT token encoding/decoding
  - `kaminari` -- pagination
  - `active_model_serializers` (~> 0.10) -- JSON serialization
  - `solid_queue` / `solid_cache` / `solid_cable` -- Rails 8 defaults (DB-backed Active Job, cache, cable)
  - `puma` -- web server
  - `image_processing` -- Active Storage

### Architecture Pattern
- **Detected**: Simple MVC / Rails-conventional
- **Evidence**: Two controllers (`TasksController`, `AuthenticationController`) inheriting from `ApplicationController < ActionController::API`. Models (`Task`, `User`) with scopes and validations. A single service class (`JsonWebToken`) in `app/services/`. Serializers in `app/serializers/`. No service objects pattern beyond JWT, no repository/port/adapter layers.
- **Dependency direction**: Controllers -> Models (directly), Controllers use `current_user` set by `ApplicationController#authenticate_request`. `JsonWebToken` service is called from both `ApplicationController` and `AuthenticationController`.

### Test Infrastructure
- **Framework**: RSpec (`rspec-rails`)
- **Location**: `spec/` directory with `spec/models/`, `spec/requests/`, `spec/factories/`, `spec/support/`, `spec/jobs/` (empty), `spec/swagger/` (empty)
- **Naming**: `*_spec.rb`
- **Run command**: `bundle exec rspec` (`.rspec` file: `--require spec_helper --format documentation`)
- **Mocking**: RSpec mocks (`config.mock_with :rspec`, `verify_partial_doubles = true`)
- **Supporting gems**: `factory_bot_rails` (factories for User and Task), `shoulda-matchers`, `database_cleaner-active_record` (truncation strategy), `simplecov` (coverage, filters `/spec/`)
- **Integration test setup**: PostgreSQL test DB (`task_manager_api_test`), DatabaseCleaner with transaction strategy (truncation for JS-tagged specs), `AuthHelper` module providing `auth_headers(user)` for request specs
- **Test counts**: 4 request spec files, 2 model spec files, 0 job specs

### Project Conventions
- **CLAUDE.md**: Absent
- **Linting**: RuboCop via `rubocop-rails-omakase` gem, run in CI (`bin/rubocop -f github`)
- **Commit style**: Short prefix convention observed -- `Day-8/feat:`, `Add`, `Refactor` prefixes
- **Code patterns**:
  - JWT auth via `Authorization: Bearer <token>` header, decoded in `ApplicationController#authenticate_request`
  - `current_user` scoping on all task queries (`current_user.tasks`) for authorization
  - Global error handling via `rescue_from` in `ApplicationController` (RecordNotFound -> 404, RecordInvalid -> 422, ParameterMissing -> 400)
  - ActiveModelSerializers default adapter set to `:json` (wraps responses in root key)
  - Kaminari pagination with meta hash in index responses
  - Request specs use `auth_headers(user)` helper from `spec/support/auth_helper.rb`

### Change Area
- **Existing code relevant to Sidekiq/Redis**:
  - `solid_queue` gem is in Gemfile (Rails 8 default Active Job backend) -- will need to be replaced/supplemented by Sidekiq
  - `ApplicationJob` base class exists at `app/jobs/application_job.rb` (empty, standard)
  - `spec/jobs/` directory exists but is empty
  - CI workflow has Redis service **commented out** (Valkey/Redis on port 6379) -- ready to be uncommented
  - CI env var `REDIS_URL` is commented out
  - `ApplicationMailer` exists with default `from@example.com`, no custom mailers yet
  - Action Mailer test delivery configured in `config/environments/test.rb`
- **Existing code relevant to Swagger/rswag**:
  - `spec/swagger/` directory exists but is empty -- suggests prior intent to add Swagger
  - No `rswag` gem in Gemfile yet
  - Routes are flat: `resources :tasks`, `post 'signup'`, `post 'login'`
- **Files to modify** (likely):
  - `Gemfile` -- add `sidekiq`, `redis`, `rswag` gems
  - `config/application.rb` -- configure Active Job adapter to Sidekiq
  - `config/routes.rb` -- mount Sidekiq web UI, mount Swagger UI
  - `app/controllers/tasks_controller.rb` -- trigger background jobs on create/update
  - `app/jobs/` -- new job classes
  - `app/mailers/` -- new task-related mailer(s)
  - `config/initializers/` -- Sidekiq initializer, rswag initializer
  - `spec/swagger/` -- Swagger definition files
  - `.github/workflows/ci.yml` -- uncomment Redis service, add REDIS_URL
- **Integration points**: `TasksController#create` and `#update` are primary hooks for enqueuing background jobs. `JsonWebToken` service for Swagger auth configuration. `ApplicationMailer` as base for task notification mailers.

### Design System
- **UI-involved**: No

### Key File Paths

| Area | Path |
|------|------|
| Gemfile | `Gemfile` |
| Routes | `config/routes.rb` |
| Application config | `config/application.rb` |
| TasksController | `app/controllers/tasks_controller.rb` |
| ApplicationController | `app/controllers/application_controller.rb` |
| AuthenticationController | `app/controllers/authentication_controller.rb` |
| Task model | `app/models/task.rb` |
| User model | `app/models/user.rb` |
| JsonWebToken service | `app/services/json_web_token.rb` |
| TaskSerializer | `app/serializers/task_serializer.rb` |
| ApplicationMailer | `app/mailers/application_mailer.rb` |
| ApplicationJob | `app/jobs/application_job.rb` |
| DB schema | `db/schema.rb` |
| Test environment | `config/environments/test.rb` |
| RSpec config | `spec/rails_helper.rb` |
| Auth test helper | `spec/support/auth_helper.rb` |
| Task factory | `spec/factories/tasks.rb` |
| User factory | `spec/factories/users.rb` |
| Tasks request spec | `spec/requests/tasks_spec.rb` |
| Auth request spec | `spec/requests/authentication_spec.rb` |
| CI workflow | `.github/workflows/ci.yml` |
