class UserTasksController < ApplicationController
  def index
    user = User.find(params[:user_id])

    unless user == current_user
      render json: { error: "Forbidden" }, status: :forbidden
      return
    end

    tasks = user.tasks

    tasks = tasks.by_status(params[:status])
    tasks = tasks.by_priority(params[:priority])
    tasks = tasks.search_by_title(params[:search])
    tasks = tasks.sorted_by(params[:sort_by], params[:order])
    tasks = tasks.page(params[:page]).per(params[:per_page])

    render json: tasks, meta: pagination_meta(tasks), adapter: :json
  end

  private

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end
end
