class TaskSerializer < ActiveModel::Serializer
  attributes :id, :title, :description, :status, :priority, :due_date, :created_at, :updated_at

  belongs_to :user

  def due_date
    object.due_date&.strftime("%Y-%m-%d")
  end

  def overdue
    return false unless object.due_date
    object.due_date < Date.today && object.status != "completed"
  end

  attribute :overdue
end
