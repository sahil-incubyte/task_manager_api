class ProfilesController < ApplicationController
  def show
    render json: profile_response(current_user)
  end

  def update
    if current_user.update(profile_params)
      render json: profile_response(current_user)
    else
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:profile).permit(:name, :email)
  end

  def profile_response(user)
    {
      profile: {
        id: user.id,
        name: user.name,
        email: user.email,
        created_at: user.created_at,
        task_count: user.tasks.count
      }
    }
  end
end
