class Task < ApplicationRecord
  belongs_to :user

  # Enums - using string values
  enum :status, { todo: "todo", in_progress: "in_progress", completed: "completed" }, validate: true
  enum :priority, { low: "low", medium: "medium", high: "high" }, validate: true

  # Validations
  validates :title, presence: true
  validates :status, presence: true
  validates :priority, presence: true

  # Scopes for filtering
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :by_priority, ->(priority) { where(priority: priority) if priority.present? }
  scope :search_by_title, ->(query) { where("title ILIKE ?", "%#{query}%") if query.present? }
  scope :by_date_range, ->(start_date, end_date) {
    where(due_date: start_date..end_date) if start_date.present? && end_date.present?
  }

  # Class method for dynamic sorting
  def self.sorted_by(sort_by, order)
    return order(created_at: :desc) if sort_by.blank?

    valid_columns = %w[created_at updated_at due_date priority title]
    valid_orders = %w[asc desc]

    column = valid_columns.include?(sort_by) ? sort_by : "created_at"
    direction = valid_orders.include?(order&.downcase) ? order.downcase : "desc"

    # Special handling for priority to sort logically (high > medium > low)
    if column == "priority"
      priority_order = direction == "asc" ?
        "CASE priority WHEN 'high' THEN 1 WHEN 'medium' THEN 2 WHEN 'low' THEN 3 END" :
        "CASE priority WHEN 'low' THEN 1 WHEN 'medium' THEN 2 WHEN 'high' THEN 3 END"
      order(Arel.sql(priority_order))
    else
      order("#{column} #{direction}")
    end
  end
end
