class Task < ApplicationRecord
  belongs_to :user

  validates :title, presence: true
  validates :status, presence: true

  # Filtering scopes
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :by_priority, ->(priority) { where(priority: priority) if priority.present? }

  # Search scope - case-insensitive title search
  scope :search_by_title, ->(query) { where("title ILIKE ?", "%#{query}%") if query.present? }

  # Date range filtering
  scope :due_before, ->(date) { where("due_date <= ?", date) if date.present? }
  scope :due_after, ->(date) { where("due_date >= ?", date) if date.present? }

  # Sorting
  SORTABLE_FIELDS = %w[created_at due_date priority].freeze
  SORT_DIRECTIONS = %w[asc desc].freeze

  scope :sorted_by, ->(field, direction = "asc") {
    field = field.to_s
    direction = direction.to_s.downcase

    field = "created_at" unless SORTABLE_FIELDS.include?(field)
    direction = "asc" unless SORT_DIRECTIONS.include?(direction)

    order(field => direction)
  }
end
