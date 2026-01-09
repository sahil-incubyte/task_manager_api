# spec/models/task_spec.rb
require 'rails_helper'

RSpec.describe Task, type: :model do
  it { should validate_presence_of(:title) }

  it { should belong_to(:user) }

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

  it "is invalid without title" do
    task = Task.new
    expect(task).not_to be_valid
  end

  it "is invalid without user" do
    task = Task.new(title: "Test")
    expect(task).not_to be_valid
  end

  it "has many tasks" do
    assoc = User.reflect_on_association(:tasks)
    expect(assoc.macro).to eq :has_many
  end

  it "belongs to user" do
    assoc = Task.reflect_on_association(:user)
    expect(assoc.macro).to eq :belongs_to
  end
end
