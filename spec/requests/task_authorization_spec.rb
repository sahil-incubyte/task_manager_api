require 'rails_helper'

RSpec.describe "Task Authorization", type: :request do
  let!(:user_a) do
    User.create!(
      name: "User A",
      email: "a@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  let!(:user_b) do
    User.create!(
      name: "User B",
      email: "b@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  let(:token) { JsonWebToken.encode(user_id: user_b.id) }

  let(:headers) do
    {
      "Authorization" => "Bearer #{token}",
      "Content-Type" => "application/json"
    }
  end

  let!(:task_a) do
    Task.create!(
      title: "User A Task",
      status: "pending",
      priority: "medium",
      user: user_a
    )
  end

  let(:token_b) { JsonWebToken.encode(user_id: user_b.id) }

  it "prevents accessing another user's task" do
    get "/tasks/#{task_a.id}", headers: {
      "Authorization" => "Bearer #{token_b}"
    }

    expect(response).to have_http_status(:not_found)
  end

  it "prevents updating another user's task" do
    patch "/tasks/#{task_a.id}",
          params: { task: { title: "Hacked title" } }.to_json,
          headers: headers

    expect(response).to have_http_status(:not_found)
  end
end
