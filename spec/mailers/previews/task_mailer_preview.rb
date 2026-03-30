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
