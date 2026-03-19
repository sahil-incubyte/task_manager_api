class TaskCleanupJob < ApplicationJob
  queue_as :default

  def perform
    Task.where(status: "completed").where("updated_at < ?", 30.days.ago).delete_all
  end
end
