# Task Manager API — Background Jobs & API Documentation Spec

## Overview

Enhance the Task Manager API with background job processing using Sidekiq/Redis and interactive API documentation using Swagger (rswag). This builds on the existing Rails 8 API with JWT authentication, pagination, filtering, sorting, and serializers.

---

## 1. Background Jobs with Sidekiq

### 1.1 Prerequisites — Redis Installation & Verification

Before configuring Sidekiq, Redis must be installed and running:

**Install Redis:**
```bash
# Ubuntu/Debian
sudo apt-get install redis-server

# macOS
brew install redis
```

**Start Redis:**
```bash
# Linux (systemd)
sudo systemctl start redis
sudo systemctl enable redis   # start on boot

# macOS
brew services start redis
```

**Verify Redis is running:**
```bash
redis-cli ping
# Expected output: PONG
```

If `redis-cli ping` does not return `PONG`, Sidekiq will fail to connect. Troubleshoot with `sudo systemctl status redis` or check `/var/log/redis/redis-server.log`.

### 1.2 Setup & Configuration

- Install `sidekiq` gem and configure Redis as the backend
- Configure Active Job to use Sidekiq as the queue adapter (`config.active_job.queue_adapter = :sidekiq`)
- Add `config/sidekiq.yml` with queue definitions, priorities, and concurrency settings
- Mount Sidekiq web dashboard at `/sidekiq` (protected — see Section 1.8)
- Redis connection configured via `REDIS_URL` environment variable (default: `redis://localhost:6379/0`)

**Sidekiq Redis initializer** — `config/initializers/sidekiq.rb`:

```ruby
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end
```

### 1.3 Job Queues & Priorities

Define separate queues with priority ordering in `config/sidekiq.yml`:

```yaml
:concurrency: 5
:queues:
  - [critical, 3]
  - [mailers, 2]
  - [default, 1]
```

| Queue | Purpose | Priority |
|-------|---------|----------|
| `critical` | Reserved for future urgent jobs | Highest (3) |
| `mailers` | Email notification jobs (`TaskNotificationJob`) | Medium (2) |
| `default` | Scheduled/maintenance jobs (`TaskCleanupJob`) | Normal (1) |

Jobs must declare their queue explicitly via `queue_as`.

### 1.4 Creating Jobs with Rails Generators

Use the Rails generator to create job files with the correct structure:

```bash
# Generate TaskNotificationJob
rails generate job TaskNotification

# Generate TaskCleanupJob
rails generate job TaskCleanup
```

This creates:
- `app/jobs/task_notification_job.rb` — the job class with `perform` method stub
- `spec/jobs/task_notification_job_spec.rb` — the test file (when using rspec-rails)

The generator ensures correct class naming, `ApplicationJob` inheritance, and places files in the right directories. After generating, customize the `queue_as`, `retry_on`, and `perform` method.

### 1.5 TaskNotificationJob

**Purpose:** Send email notifications when tasks are created or completed.

**Queue:** `mailers`

**Trigger — Task Creation:**
- When `POST /tasks` successfully creates a task, enqueue `TaskNotificationJob.perform_later(task.id, "created")`
- Job calls `TaskMailer.task_created(task).deliver_now`
- If task creation fails (validation error), no job is enqueued

**Trigger — Task Completion:**
- When `PATCH /tasks/:id` changes status to `"completed"`, enqueue `TaskNotificationJob.perform_later(task.id, "completed")`
- Job calls `TaskMailer.task_completed(task).deliver_now`
- No job enqueued if status changes to anything other than `"completed"`
- No job enqueued if the update does not change the status field

**Error Handling:**
- If the task no longer exists when the job runs (deleted between enqueue and execution), the job should gracefully exit without raising
- Configure `retry: 3` for transient failures (e.g., SMTP timeout)
- Discard on `ActiveJob::DeserializationError`

### 1.6 TaskCleanupJob

**Purpose:** Remove stale completed tasks older than 30 days.

**Queue:** `default`

**Behavior:**
- Deletes all tasks where `status = "completed"` AND `updated_at < 30.days.ago`
- Does nothing if no matching tasks exist

**Scheduling:** Runs daily via `sidekiq-cron` (see Section 1.9).

### 1.7 TaskMailer

**`task_created(task)` email:**
- **To:** `task.user.email`
- **From:** `from@example.com` (ApplicationMailer default)
- **Subject:** `"New Task Created: #{task.title}"`
- **Body:** Includes task title, status, priority, due date

**`task_completed(task)` email:**
- **To:** `task.user.email`
- **From:** `from@example.com`
- **Subject:** `"Task Completed: #{task.title}"`
- **Body:** Includes task title and a completion confirmation message

**Mailer views:** Create both HTML (`*.html.erb`) and text (`*.text.erb`) templates under `app/views/task_mailer/`.

**Action Mailer Configuration:**

| Environment | `delivery_method` | `queue_adapter` | Notes |
|-------------|-------------------|-----------------|-------|
| development | `:letter_opener` | `:sidekiq` | Emails open in browser automatically |
| test | `:test` | `:test` | Emails collected in `ActionMailer::Base.deliveries` |
| production | `:smtp` | `:sidekiq` | Real SMTP credentials via ENV vars |

Set `config.action_mailer.deliver_later_queue_name = "mailers"` in each environment so mailer jobs land in the correct Sidekiq queue.

**Development dependency:** Add `letter_opener` gem to the development group in Gemfile for previewing emails in the browser.

**Mailer Previews:**

Create `spec/mailers/previews/task_mailer_preview.rb` (or `test/mailers/previews/`) to visually preview emails during development:

```ruby
class TaskMailerPreview < ActionMailer::Preview
  def task_created
    task = Task.first || FactoryBot.create(:task)
    TaskMailer.task_created(task)
  end

  def task_completed
    task = Task.first || FactoryBot.create(:task, :completed)
    TaskMailer.task_completed(task)
  end
end
```

Access previews at:
- `http://localhost:3000/rails/mailers/task_mailer/task_created`
- `http://localhost:3000/rails/mailers/task_mailer/task_completed`

This lets you inspect email HTML/text rendering without actually sending emails.

### 1.8 Sidekiq Dashboard Authentication

Mount the Sidekiq web UI at `/sidekiq` in `config/routes.rb` with access protection:

**Development:** Open access (no auth required).

**Production:** Protect with HTTP basic auth using a Rack middleware constraint:

```ruby
# config/routes.rb
require 'sidekiq/web'

Sidekiq::Web.use Rack::Auth::Basic do |username, password|
  ActiveSupport::SecurityUtils.secure_compare(username, ENV.fetch("SIDEKIQ_USERNAME")) &
  ActiveSupport::SecurityUtils.secure_compare(password, ENV.fetch("SIDEKIQ_PASSWORD"))
end

mount Sidekiq::Web => '/sidekiq'
```

Required ENV vars for production: `SIDEKIQ_USERNAME`, `SIDEKIQ_PASSWORD`.

### 1.9 Scheduled Jobs & Cron

Install `sidekiq-cron` gem for recurring job scheduling.

**Configuration** — `config/initializers/sidekiq_cron.rb`:

```ruby
Sidekiq::Cron::Job.create(
  name:  'TaskCleanupJob - daily at midnight',
  cron:  '0 0 * * *',
  class: 'TaskCleanupJob'
)
```

This runs `TaskCleanupJob` every day at 00:00 UTC.

**Monitoring:** Scheduled jobs are visible in the Sidekiq web dashboard under the "Cron" tab.

### 1.10 `perform_later` vs `perform_now`

| Method | When to Use | Behavior |
|--------|-------------|----------|
| `perform_later` | Controllers, callbacks, production code | Enqueues the job to Redis; Sidekiq picks it up asynchronously. Non-blocking. |
| `perform_now` | Tests, debugging, one-off console tasks | Executes the job inline, synchronously, in the current process. Blocks until complete. |

**Why this matters:**
- `perform_later` requires a running Sidekiq process and Redis. If Redis is down, the job silently fails to enqueue.
- `perform_now` bypasses the queue entirely — useful in tests to verify job logic without needing Sidekiq running.
- In the **test environment**, `config.active_job.queue_adapter = :test` makes `perform_later` store jobs in memory instead of Redis. Use `have_enqueued_job` matcher to assert jobs were enqueued, and `perform_enqueued_jobs` block to execute them inline when needed.
- **Sidekiq does NOT need to be running for tests.** The `:test` adapter is purely in-memory. No Redis connection required in CI either.

### 1.11 Job Arguments & Serialization

Active Job serializes arguments to JSON before sending them to the queue backend (Redis). This imposes constraints:

**Allowed argument types:**
- Basic types: `String`, `Integer`, `Float`, `NilClass`, `TrueClass`, `FalseClass`
- `Hash`, `Array` (with allowed types as values)
- `ActiveSupport::HashWithIndifferentAccess`
- `Date`, `Time`, `DateTime`, `BigDecimal`
- ActiveRecord objects (serialized via GlobalID — see below)

**Why we pass `task.id` instead of `task`:**
- Passing an ActiveRecord object uses **GlobalID** serialization: Rails stores a URI like `gid://task-manager-api/Task/42` and reloads the record when the job runs.
- If the record is deleted between enqueue and execution, `perform` raises `ActiveJob::DeserializationError`. That's why we configure `discard_on ActiveJob::DeserializationError`.
- Passing the plain `id` (an Integer) and calling `Task.find_by(id:)` inside the job gives us explicit control — we can handle "record missing" without relying on the discard mechanism.
- **Our approach:** Pass `task.id` (Integer) and `notification_type` (String). Look up the record inside `#perform`. Return early if not found.

```ruby
# Inside TaskNotificationJob#perform
def perform(task_id, notification_type)
  task = Task.find_by(id: task_id)
  return unless task
  # ... send email
end
```

### 1.12 Controller Changes

**TasksController#create:**
```
After successful task.save:
  TaskNotificationJob.perform_later(task.id, "created")
```

**TasksController#update:**
```
After successful task.update:
  if task status changed to "completed":
    TaskNotificationJob.perform_later(task.id, "completed")
```

No changes to existing response formats or status codes.

### 1.13 Running Sidekiq in Development — Procfile

Create a `Procfile.dev` to start Rails, Sidekiq, and (optionally) Redis together:

```
web: bin/rails server -p 3000
worker: bundle exec sidekiq -C config/sidekiq.yml
```

Run everything with `foreman` or `overmind`:

```bash
# Using foreman
gem install foreman
foreman start -f Procfile.dev

# Using overmind (recommended — supports tmux, individual process restart)
brew install overmind   # macOS
overmind start -f Procfile.dev
```

This ensures Sidekiq is always running alongside the Rails server in development. Without a running Sidekiq process, `perform_later` jobs will sit in Redis indefinitely.

### 1.14 TaskExportJob (Out of Scope — Future Enhancement)

The requirements mention "processing uploads or exports" as a use case. This spec does **not** implement an export job, but documents it as a future enhancement for reference:

**Potential `TaskExportJob`:**
- Generates a CSV of all tasks for a given user
- Stores the file via Active Storage
- Sends an email with a download link when complete
- Queue: `default`

This is excluded from the current scope to keep the implementation focused on notification and cleanup patterns. It can be added as a follow-up once the Sidekiq infrastructure is in place.

---

## 2. API Documentation with Swagger (rswag)

### 2.1 Setup & Configuration

- Install `rswag` gem (`rswag-api`, `rswag-ui`, `rswag-specs`)
- Run `rails generate rswag:install` to set up
- Mount Swagger UI at `/api-docs`
- Configure `swagger_helper.rb` with API metadata:
  - **Title:** Task Manager API
  - **Version:** v1
  - **Description:** RESTful API for managing tasks with JWT authentication
  - **Base URL:** `http://localhost:3000`

**`spec/swagger_helper.rb` structure:**

```ruby
RSpec.configure do |config|
  config.openapi_root = Rails.root.join('swagger').to_s

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
```

### 2.2 Security Scheme

Define a Bearer JWT security scheme in the Swagger spec (included in `swagger_helper.rb` above):

```yaml
securityDefinitions:
  Bearer:
    type: apiKey
    name: Authorization
    in: header
    description: "Enter: Bearer <your_jwt_token>"
```

### 2.3 Reusable Schema Definitions

Define shared schemas in `swagger_helper.rb` under `components.schemas` to avoid repeating the same structure across endpoints:

| Schema | Used By | Properties |
|--------|---------|------------|
| `Task` | GET /tasks, GET /tasks/:id, POST /tasks, PATCH /tasks/:id | id, title, description, status, priority, due_date, created_at, updated_at |
| `PaginationMeta` | GET /tasks | current_page, total_pages, total_count, per_page |
| `ErrorResponse` | All error responses (401, 404) | error (string) |
| `ValidationErrorResponse` | 422 responses | errors (array of strings) |

Reference these in endpoint specs with `schema '$ref' => '#/components/schemas/Task'` instead of inlining the same properties repeatedly.

### 2.4 Endpoint Documentation

Each endpoint must document: summary, description, parameters, request body (if applicable), and all possible responses with examples.

#### Authentication Endpoints

**POST /signup**
- Summary: Register a new user
- Request body: `{ name, email, password, password_confirmation }`
- Responses:
  - `201`: `{ token: "jwt_token_here" }`
  - `422`: `{ errors: ["Email has already been taken"] }`

**POST /login**
- Summary: Authenticate user
- Request body: `{ email, password }`
- Responses:
  - `200`: `{ token: "jwt_token_here" }`
  - `401`: `{ error: "Invalid email or password" }`

#### Task Endpoints (all require Bearer token)

**GET /tasks**
- Summary: List tasks with pagination, filtering, searching, and sorting
- Parameters (all query, all optional):
  - `page` (integer) — Page number
  - `per_page` (integer) — Items per page
  - `status` (string, enum: todo, in_progress, completed, pending) — Filter by status
  - `priority` (integer, enum: 1, 2, 3) — Filter by priority
  - `search` (string) — Search tasks by title (case-insensitive)
  - `sort_by` (string, enum: created_at, due_date, priority) — Sort field
  - `order` (string, enum: asc, desc) — Sort direction
  - `due_before` (date) — Filter tasks due on or before date
  - `due_after` (date) — Filter tasks due on or after date
- Responses:
  - `200`:
    ```json
    {
      "tasks": [
        {
          "id": 1,
          "title": "Build API",
          "description": "Create REST endpoints",
          "status": "in_progress",
          "priority": 2,
          "due_date": "2026-04-01",
          "created_at": "2026-03-18T10:00:00Z",
          "updated_at": "2026-03-18T10:00:00Z"
        }
      ],
      "meta": {
        "current_page": 1,
        "total_pages": 3,
        "total_count": 25,
        "per_page": 10
      }
    }
    ```
  - `401`: `{ error: "Unauthorized" }`

**GET /tasks/:id**
- Summary: Get a specific task
- Parameters: `id` (path, required, integer)
- Responses:
  - `200`: `{ task: { id, title, description, status, priority, due_date, created_at, updated_at } }`
  - `401`: `{ error: "Unauthorized" }`
  - `404`: `{ error: "Couldn't find Task with 'id'=..." }`

**POST /tasks**
- Summary: Create a new task (enqueues notification email)
- Request body:
  ```json
  {
    "task": {
      "title": "string (required)",
      "description": "string",
      "status": "string (required)",
      "priority": "integer",
      "due_date": "date"
    }
  }
  ```
- Responses:
  - `201`: `{ task: { ... } }`
  - `401`: `{ error: "Unauthorized" }`
  - `422`: `{ errors: ["Title can't be blank", "Status can't be blank"] }`

**PATCH /tasks/:id**
- Summary: Update a task (enqueues notification if status changes to completed)
- Parameters: `id` (path, required, integer)
- Request body: `{ task: { title, description, status, priority, due_date } }` (all optional)
- Responses:
  - `200`: `{ task: { ... } }`
  - `401`: `{ error: "Unauthorized" }`
  - `404`: `{ error: "Couldn't find Task with 'id'=..." }`
  - `422`: `{ errors: [...] }`

**DELETE /tasks/:id**
- Summary: Delete a task
- Parameters: `id` (path, required, integer)
- Responses:
  - `204`: No content
  - `401`: `{ error: "Unauthorized" }`
  - `404`: `{ error: "Couldn't find Task with 'id'=..." }`

### 2.5 Swagger Spec Files

Write rswag integration specs under `spec/swagger/` (or `spec/requests/` with rswag DSL):
- `spec/swagger/authentication_spec.rb` — POST /signup, POST /login
- `spec/swagger/tasks_spec.rb` — All task CRUD endpoints

These specs serve dual purpose: they generate the Swagger JSON **and** act as integration tests.

### 2.6 Generated Output

- `swagger/v1/swagger.yaml` — Auto-generated OpenAPI spec
- Swagger UI accessible at `/api-docs` showing all endpoints interactively
- Users can test endpoints directly from the browser using the "Try it out" feature

### 2.7 Keeping Docs Up-to-Date

Swagger docs can go stale when endpoints change but the rswag specs aren't updated. Prevent this with:

**1. CI Check — Add to `.github/workflows/ci.yml`:**

```yaml
- name: Verify Swagger docs are up-to-date
  run: |
    bundle exec rails rswag:specs:swaggerize
    git diff --exit-code swagger/
```

This regenerates the Swagger YAML and fails the build if the checked-in file differs from what rswag produces — meaning someone changed an endpoint without updating the docs.

**2. Rake Task — `lib/tasks/swagger.rake`:**

```ruby
namespace :swagger do
  desc "Regenerate Swagger docs and check for drift"
  task verify: :environment do
    system("bundle exec rails rswag:specs:swaggerize")
    if system("git diff --quiet swagger/")
      puts "Swagger docs are up-to-date."
    else
      abort "Swagger docs are stale! Run `rails rswag:specs:swaggerize` and commit."
    end
  end
end
```

**3. Developer Workflow:**
- After changing any endpoint, run `rails rswag:specs:swaggerize` to regenerate
- Commit the updated `swagger/v1/swagger.yaml` alongside the code change
- CI enforces this — PRs with stale docs will fail

---

## 3. Files to Create / Modify

### New Files

| File | Purpose |
|------|---------|
| `app/jobs/task_notification_job.rb` | Sends email notifications async (queue: `mailers`) |
| `app/jobs/task_cleanup_job.rb` | Removes old completed tasks (queue: `default`) |
| `app/mailers/task_mailer.rb` | Defines `task_created` and `task_completed` emails |
| `app/views/task_mailer/task_created.html.erb` | HTML email template for task creation |
| `app/views/task_mailer/task_created.text.erb` | Text email template for task creation |
| `app/views/task_mailer/task_completed.html.erb` | HTML email template for task completion |
| `app/views/task_mailer/task_completed.text.erb` | Text email template for task completion |
| `spec/mailers/previews/task_mailer_preview.rb` | Mailer previews for dev (viewable at /rails/mailers) |
| `config/sidekiq.yml` | Sidekiq queues (`critical`, `mailers`, `default`) and concurrency |
| `config/initializers/sidekiq.rb` | Redis connection config for Sidekiq server and client |
| `config/initializers/sidekiq_cron.rb` | Cron schedule for `TaskCleanupJob` (daily at midnight) |
| `Procfile.dev` | Runs Rails + Sidekiq together in development |
| `lib/tasks/swagger.rake` | Rake task to verify Swagger docs are not stale |
| `spec/jobs/task_notification_job_spec.rb` | Tests for notification job |
| `spec/jobs/task_cleanup_job_spec.rb` | Tests for cleanup job |
| `spec/mailers/task_mailer_spec.rb` | Tests for mailer |
| `spec/requests/tasks_background_jobs_spec.rb` | Integration tests — controller enqueues correct jobs |
| `spec/swagger/authentication_spec.rb` | Swagger spec for auth endpoints |
| `spec/swagger/tasks_spec.rb` | Swagger spec for task CRUD endpoints |
| `spec/swagger_helper.rb` | Swagger config with schemas and security definitions |
| `swagger/v1/swagger.yaml` | Auto-generated OpenAPI doc (committed to repo) |

### Modified Files

| File | Change |
|------|--------|
| `Gemfile` | Add `sidekiq`, `sidekiq-cron`, `letter_opener`, `rswag-api`, `rswag-ui`, `rswag-specs` |
| `config/routes.rb` | Mount `Sidekiq::Web => '/sidekiq'` and Swagger UI via rswag |
| `config/environments/development.rb` | `queue_adapter = :sidekiq`, `deliver_later_queue_name = "mailers"`, `delivery_method = :letter_opener` |
| `config/environments/test.rb` | `queue_adapter = :test`, `deliver_later_queue_name = "mailers"`, `delivery_method = :test` |
| `config/environments/production.rb` | `queue_adapter = :sidekiq`, `deliver_later_queue_name = "mailers"`, `delivery_method = :smtp` with ENV credentials |
| `app/controllers/tasks_controller.rb` | Add `perform_later` calls in `create` and `update` |
| `.github/workflows/ci.yml` | Add Swagger docs staleness check step |

---

## 4. Gem Dependencies

| Gem | Group | Purpose |
|-----|-------|---------|
| `sidekiq` | default | Background job processing with Redis |
| `sidekiq-cron` | default | Cron-based recurring job scheduling |
| `letter_opener` | development | Preview emails in browser without sending |
| `rswag-api` | default | Serves Swagger JSON from Rails |
| `rswag-ui` | default | Mounts Swagger UI at `/api-docs` |
| `rswag-specs` | development, test | RSpec DSL for writing Swagger specs |

---

## 5. Testing Requirements

### Job Specs
- `TaskNotificationJob` enqueues correctly with proper arguments and on the `mailers` queue
- `TaskNotificationJob#perform` sends emails via `TaskMailer`
- `TaskNotificationJob` handles missing tasks gracefully (no error raised)
- `TaskNotificationJob` retries up to 3 times on transient failure
- `TaskCleanupJob` enqueues on the `default` queue
- `TaskCleanupJob` deletes only old completed tasks (>30 days)
- `TaskCleanupJob` leaves recent completed and non-completed tasks untouched

### Mailer Specs
- `TaskMailer#task_created` has correct subject, recipient, sender, and body content
- `TaskMailer#task_completed` has correct subject, recipient, sender, and body content
- Both emails deliver successfully via `deliver_now`

### Integration Specs (Controller + Jobs)
- `POST /tasks` enqueues `TaskNotificationJob` with `(task.id, "created")`
- `POST /tasks` does NOT enqueue job on validation failure
- `PATCH /tasks/:id` enqueues job when status changes to `"completed"`
- `PATCH /tasks/:id` does NOT enqueue job for non-completion status changes
- `PATCH /tasks/:id` does NOT enqueue job for non-status updates (e.g., title change)
- All existing tests continue to pass unchanged

### Swagger Specs
- All 7 endpoints documented with request/response schemas
- Swagger JSON generates without errors (`rails rswag:specs:swaggerize`)
- Swagger UI loads at `/api-docs`
- CI check catches stale Swagger docs

### Test Environment Notes
- **No Redis or Sidekiq process needed for tests.** The `:test` queue adapter is purely in-memory.
- Use `have_enqueued_job` matcher to assert jobs were enqueued via `perform_later`
- Use `perform_enqueued_jobs { ... }` block when you need to execute enqueued jobs inline during a test
- CI pipeline does NOT need a Redis service for the test suite

---

## 6. Success Criteria

- [ ] Redis installed, running, and verified (`redis-cli ping` returns `PONG`)
- [x] `sidekiq` gem installed and configured with Redis initializer
- [x] `config/sidekiq.yml` defines `critical`, `mailers`, and `default` queues with priorities
- [ ] Jobs generated with `rails generate job` (correct structure and naming)
- [x] `TaskNotificationJob` created with `perform_later`, `queue_as :mailers`, and `retry: 3`
- [x] `TaskCleanupJob` created with `queue_as :default` for scheduled cleanup
- [x] `sidekiq-cron` configured to run `TaskCleanupJob` daily at midnight
- [x] `TaskMailer` with `task_created` and `task_completed` actions and HTML/text views
- [x] Mailer previews accessible at `/rails/mailers/task_mailer/*` in development
- [x] Action Mailer configured per-environment (delivery method, queue name)
- [x] `letter_opener` gem installed for development email previews
- [x] Email sent in background on task creation via `perform_later`
- [x] Email sent in background when task status changes to completed
- [x] No job enqueued on failed task creation or non-completion updates
- [x] Job gracefully handles deleted tasks (no error raised)
- [x] Sidekiq dashboard mounted at `/sidekiq` with basic auth in production
- [x] `Procfile.dev` created to run Rails + Sidekiq together
- [x] `rswag` installed and configured with `swagger_helper.rb`
- [x] Reusable schemas defined (`Task`, `PaginationMeta`, `ErrorResponse`, `ValidationErrorResponse`)
- [x] All API endpoints documented with Swagger (schemas, examples, auth)
- [x] Swagger UI accessible at `/api-docs` with interactive "Try it out"
- [x] CI step verifies Swagger docs are not stale
- [x] RSpec tests cover jobs, mailers, and controller-job integration
- [x] All existing tests still pass
- [x] `bundle exec rspec` — all green
