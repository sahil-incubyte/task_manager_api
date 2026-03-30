class TaskMailer < ApplicationMailer
  def task_created(task)
    @task = task
    mail(to: task.user.email, subject: "New Task Created: #{task.title}")
  end

  def task_completed(task)
    @task = task
    mail(to: task.user.email, subject: "Task Completed: #{task.title}")
  end
end
