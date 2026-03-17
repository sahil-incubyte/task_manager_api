# spec/models/task_spec.rb
require 'rails_helper'

RSpec.describe Task, type: :model do
  it { should validate_presence_of(:title) }
  it { should validate_presence_of(:status) }
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
    task = Task.new(title: "Test", status: "pending")
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

  # Scope tests
  describe "scopes" do
    let(:user) { create(:user) }
    let!(:todo_task) { create(:task, :todo, title: "Buy milk", priority: 1, due_date: Date.today + 1, user: user) }
    let!(:completed_task) { create(:task, :completed, title: "Buy eggs", priority: 3, due_date: Date.today + 10, user: user) }
    let!(:in_progress_task) { create(:task, :in_progress, title: "Clean room", priority: 2, due_date: Date.today + 5, user: user) }

    describe ".by_status" do
      it "filters by status" do
        expect(Task.by_status("todo")).to contain_exactly(todo_task)
      end

      it "returns all when status is nil" do
        expect(Task.by_status(nil).count).to eq(3)
      end
    end

    describe ".by_priority" do
      it "filters by priority" do
        expect(Task.by_priority(3)).to contain_exactly(completed_task)
      end
    end

    describe ".search_by_title" do
      it "searches case-insensitively" do
        expect(Task.search_by_title("buy")).to contain_exactly(todo_task, completed_task)
      end

      it "returns all when query is nil" do
        expect(Task.search_by_title(nil).count).to eq(3)
      end
    end

    describe ".due_before" do
      it "returns tasks due before given date" do
        expect(Task.due_before(Date.today + 3)).to contain_exactly(todo_task)
      end
    end

    describe ".due_after" do
      it "returns tasks due after given date" do
        expect(Task.due_after(Date.today + 7)).to contain_exactly(completed_task)
      end
    end

    describe ".sorted_by" do
      it "sorts by priority ascending" do
        expect(Task.sorted_by("priority", "asc").pluck(:priority)).to eq([1, 2, 3])
      end

      it "sorts by priority descending" do
        expect(Task.sorted_by("priority", "desc").pluck(:priority)).to eq([3, 2, 1])
      end

      it "defaults to created_at for invalid field" do
        expect(Task.sorted_by("hacked", "asc").pluck(:id)).to eq([todo_task.id, completed_task.id, in_progress_task.id])
      end

      it "defaults to asc for invalid direction" do
        expect(Task.sorted_by("priority", "invalid").pluck(:priority)).to eq([1, 2, 3])
      end
    end
  end
end
