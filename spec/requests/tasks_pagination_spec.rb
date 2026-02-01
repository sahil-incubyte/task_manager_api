require 'rails_helper'

RSpec.describe "Tasks Pagination", type: :request do
  let(:user) { create(:user) }
  let(:token) { JsonWebToken.encode(user_id: user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  before do
    create_list(:task, 25, user: user)
  end

  it "returns paginated tasks" do
    get "/tasks?page=1&per=10", headers: headers

    json = JSON.parse(response.body)

    expect(json["tasks"].size).to eq(10)
    expect(json["meta"]["current_page"]).to eq(1)
    expect(json["meta"]["total_pages"]).to eq(3)
  end
end
