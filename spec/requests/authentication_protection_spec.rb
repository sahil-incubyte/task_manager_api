require 'rails_helper'

RSpec.describe "Authentication Protection", type: :request do
  describe "Protected endpoints" do
    it "returns unauthorized without token" do
      get "/tasks"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
