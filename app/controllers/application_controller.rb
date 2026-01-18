class ApplicationController < ActionController::API
  before_action :authenticate_request

  private
  def authenticate_request
    header = request.headers['Authorization']
    token = header&.split(' ')&.last

    decoded = JsonWebToken.decode(token)

    if decoded
      @current_user = User.find(decoded[:user_id])
    else
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end
end
