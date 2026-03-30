class TaskNotificationJob < ApplicationJob
  queue_as :mailers

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError

  NOTIFICATION_TYPES = {
    "created" => :task_created,
    "completed" => :task_completed
  }.freeze

  def perform(task_id, notification_type)
    task = Task.find_by(id: task_id)
    return unless task

    mailer_method = NOTIFICATION_TYPES[notification_type]
    return unless mailer_method

    TaskMailer.public_send(mailer_method, task).deliver_now
  end
end
