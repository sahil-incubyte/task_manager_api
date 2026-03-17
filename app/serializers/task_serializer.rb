class TaskSerializer < ActiveModel::Serializer
  attributes :id, :title, :description, :status, :priority, :due_date, :created_at, :updated_at
end
