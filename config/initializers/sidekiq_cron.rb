Sidekiq::Cron::Job.create(
  name: "TaskCleanupJob - daily at midnight",
  cron: "0 0 * * *",
  class: "TaskCleanupJob"
)
