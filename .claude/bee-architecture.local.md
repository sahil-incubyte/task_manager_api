## Architecture

**Pattern**: Rails-conventional MVC (no change)
**Start with**: Continue existing pattern. Jobs in app/jobs/, mailers in app/mailers/, swagger specs in spec/swagger/
**File structure**:
  - app/jobs/task_notification_job.rb, task_cleanup_job.rb
  - app/mailers/task_mailer.rb
  - app/views/task_mailer/*.html.erb, *.text.erb
  - config/initializers/sidekiq.rb, sidekiq_cron.rb
  - config/sidekiq.yml
  - spec/jobs/, spec/mailers/, spec/swagger/
  - spec/swagger_helper.rb
  - lib/tasks/swagger.rake
  - swagger/v1/swagger.yaml
**Key boundaries**: Active Job is the boundary between controllers and job processing (perform_later). TaskMailer is the boundary between jobs and email delivery.
**Dependency direction**: Controller -> Job (via perform_later) -> Mailer (via deliver_now). Never the reverse. Swagger specs are a parallel concern with no runtime dependencies.

## Evolution Triggers
- "If multiple events need to trigger notifications beyond create/complete -> extract a Notifiable concern or event bus"
- "If job error handling grows complex across multiple jobs -> extract a shared error handling concern in ApplicationJob"
- "If more than 3 mailers exist with similar patterns -> extract shared mailer helpers or a notification service"

## Slice Order
Infrastructure -> Mailer -> NotificationJob -> CleanupJob -> Controller Integration -> Swagger

## Proposed Slices

### Slice 1: Sidekiq Infrastructure Setup
- Add `sidekiq`, `sidekiq-cron`, `letter_opener` gems to Gemfile
- Create `config/initializers/sidekiq.rb` (Redis connection)
- Create `config/sidekiq.yml` (queue definitions: critical, mailers, default)
- Configure Active Job adapter per environment (sidekiq for dev/prod, test for test)
- Configure Action Mailer `deliver_later_queue_name = "mailers"` per environment
- Mount Sidekiq web UI at `/sidekiq` with basic auth for production
- Create `Procfile.dev`
- **Verify:** `bundle install` succeeds, Sidekiq config loads without errors, routes include `/sidekiq`

### Slice 2: TaskMailer
- Create `TaskMailer` with `task_created` and `task_completed` actions
- Create HTML and text email templates (4 view files)
- Configure Action Mailer delivery method per environment (letter_opener for dev, test for test, smtp for prod)
- Create mailer preview at `spec/mailers/previews/task_mailer_preview.rb`
- **Verify:** Mailer specs pass, all existing tests still pass

### Slice 3: TaskNotificationJob
- Create `TaskNotificationJob` (queue: mailers, retry: 3, discard_on DeserializationError)
- Job takes `task_id` and `notification_type`, looks up task, calls appropriate mailer
- Graceful handling when task is missing (return early)
- **Verify:** Job specs pass

### Slice 4: TaskCleanupJob + Cron
- Create `TaskCleanupJob` (queue: default) -- deletes completed tasks older than 30 days
- Create `config/initializers/sidekiq_cron.rb` for daily midnight schedule
- **Verify:** Job specs pass

### Slice 5: Controller Integration (Jobs + Mailers)
- Modify `TasksController#create` to enqueue `TaskNotificationJob` after successful save
- Modify `TasksController#update` to enqueue job when status changes to "completed"
- **Verify:** ALL tests pass (existing + new integration tests)

### Slice 6: Swagger/rswag API Documentation
- Add `rswag-api`, `rswag-ui`, `rswag-specs` gems
- Run rswag install, configure `spec/swagger_helper.rb` with schemas and security
- Mount Swagger UI at `/api-docs`
- Write swagger specs for all endpoints
- Generate `swagger/v1/swagger.yaml`
- Create `lib/tasks/swagger.rake` for drift detection
- Add CI step for Swagger staleness check
- **Verify:** `rails rswag:specs:swaggerize` generates without errors, swagger specs pass
