class TasksController < ApplicationController
  def index
    tasks = current_user.tasks

    # Filtering
    tasks = tasks.by_status(params[:status])
    tasks = tasks.by_priority(params[:priority])

    # Search
    tasks = tasks.search_by_title(params[:search])

    # Date range filtering
    tasks = tasks.due_before(params[:due_before])
    tasks = tasks.due_after(params[:due_after])

    # Sorting
    tasks = tasks.sorted_by(params[:sort_by], params[:order])

    # Pagination
    tasks = tasks.page(params[:page]).per(params[:per_page])

    render json: tasks, meta: pagination_meta(tasks), adapter: :json
  end

  def show
    task = current_user.tasks.find(params[:id])
    render json: task
  end

  def create
    task = current_user.tasks.new(task_params)

    if task.save
      render json: task, status: :created
    else
      render json: { errors: task.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    task = current_user.tasks.find(params[:id])

    if task.update(task_params)
      render json: task
    else
      render json: { errors: task.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    task = current_user.tasks.find(params[:id])
    task.destroy
    head :no_content
  end

  def stats
    tasks = current_user.tasks

    render json: {
      stats: {
        total: tasks.count,
        by_status: tasks.group(:status).count,
        by_priority: tasks.group(:priority).count,
        overdue: tasks.where("due_date < ?", Date.today).where.not(status: "completed").count,
        due_today: tasks.where(due_date: Date.today).count
      }
    }
  end

  def complete
    task = current_user.tasks.find(params[:id])

    if task.update(status: "completed")
      render json: task
    else
      render json: { errors: task.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def search
    tasks = current_user.tasks
    tasks = tasks.search_by_title(params[:q])
    tasks = tasks.by_status(params[:status])
    tasks = tasks.page(params[:page]).per(params[:per_page])

    render json: tasks, meta: pagination_meta(tasks), adapter: :json
  end

  private

  def task_params
    params.require(:task).permit(:title, :description, :status, :priority, :due_date)
  end

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end
end
