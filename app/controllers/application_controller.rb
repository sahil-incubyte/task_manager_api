class ApplicationController < ActionController::API
  before_action :authenticate_request

  private
  def authenticate_request
    # For now, do nothing
    # We will implement JWT verification in the next step
  end
end
