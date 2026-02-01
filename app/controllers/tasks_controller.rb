class TasksController < ApplicationController
  before_action :set_task, only: [ :show, :update, :destroy ]
  before_action :authorize_task, only: [ :show, :update, :destroy ]

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid

  def index
    # Start with current user's tasks
    tasks = current_user.tasks

    # Apply filters
    tasks = apply_filters(tasks)

    # Apply search
    tasks = tasks.search_by_title(params[:search]) if params[:search].present?

    # Apply sorting
    tasks = tasks.sorted_by(params[:sort_by], params[:order])

    # Apply pagination
    page = params[:page] || 1
    per_page = params[:per] || 10

    # Ensure per_page is reasonable
    per_page = [ [ per_page.to_i, 1 ].max, 100 ].min

    paginated_tasks = tasks.page(page).per(per_page)

    render json: paginated_tasks,
           meta: pagination_meta(paginated_tasks),
           adapter: :json
  end

  def show
    render json: @task, serializer: TaskSerializer
  end

  def create
    task = current_user.tasks.build(task_params)

    if task.save
      render json: task, status: :created, serializer: TaskSerializer
    else
      render json: {
        error: "Validation failed",
        details: task.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def update
    if @task.update(task_params)
      render json: @task, serializer: TaskSerializer
    else
      render json: {
        error: "Validation failed",
        details: @task.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def destroy
    @task.destroy
    head :no_content
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end

  def authorize_task
    unless @task.user_id == current_user.id
      render json: { error: "Unauthorized access to this task" }, status: :forbidden
    end
  end

  def apply_filters(tasks)
    # Filter by status
    tasks = tasks.by_status(params[:status]) if params[:status].present?

    # Filter by priority
    tasks = tasks.by_priority(params[:priority]) if params[:priority].present?

    # Filter by date range
    if params[:start_date].present? && params[:end_date].present?
      tasks = tasks.by_date_range(params[:start_date], params[:end_date])
    end

    tasks
  end

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      next_page: collection.next_page,
      prev_page: collection.prev_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end

  def task_params
    params.require(:task).permit(
      :title, :description, :status, :priority, :due_date
    )
  end

  # Error handlers
  def record_not_found
    render json: {
      error: "Record not found",
      message: "The requested resource could not be found"
    }, status: :not_found
  end

  def record_invalid(exception)
    render json: {
      error: "Validation failed",
      details: exception.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  def internal_server_error(exception)
    # Log the error for debugging
    Rails.logger.error "Internal Server Error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    render json: {
      error: "Internal server error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end
end
