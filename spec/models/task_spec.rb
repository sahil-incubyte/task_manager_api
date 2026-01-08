# spec/models/task_spec.rb
require 'rails_helper'

RSpec.describe Task, type: :model do
  it "is valid with valid attributes" do
    user = User.create!(
      name: "Sahil",
      email: "sahil@test.com",
      password_digest: "password"
    )

    task = Task.new(
      title: "Learn Rails",
      description: "Active Record",
      status: "pending",
      priority: 1,
      due_date: Date.today,
      user: user
    )

    expect(task).to be_valid
  end
end
