require "rails_helper"

RSpec.describe TaskCleanupJob, type: :job do
  let(:user) { create(:user) }

  describe "queue configuration" do
    it "is enqueued on the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end

  describe "#perform" do
    context "when completed tasks are older than 30 days" do
      it "deletes them" do
        old_task = create(:task, :completed, user: user)
        old_task.update_column(:updated_at, 31.days.ago)

        described_class.new.perform

        expect(Task.exists?(old_task.id)).to be false
      end
    end

    context "when completed tasks are less than 30 days old" do
      it "does not delete them" do
        recent_task = create(:task, :completed, user: user)
        recent_task.update_column(:updated_at, 29.days.ago)

        described_class.new.perform

        expect(Task.exists?(recent_task.id)).to be true
      end
    end

    context "at the 30-day boundary" do
      it "does not delete a task updated exactly 29 days and 23 hours ago" do
        boundary_task = create(:task, :completed, user: user)
        boundary_task.update_column(:updated_at, 29.days.ago - 23.hours)

        described_class.new.perform

        expect(Task.exists?(boundary_task.id)).to be true
      end

      it "deletes a task updated 30 days and 1 second ago" do
        boundary_task = create(:task, :completed, user: user)
        boundary_task.update_column(:updated_at, 30.days.ago - 1.second)

        described_class.new.perform

        expect(Task.exists?(boundary_task.id)).to be false
      end
    end

    context "when tasks are not completed" do
      it "does not delete pending tasks regardless of age" do
        old_pending = create(:task, status: "pending", user: user)
        old_pending.update_column(:updated_at, 60.days.ago)

        described_class.new.perform

        expect(Task.exists?(old_pending.id)).to be true
      end

      it "does not delete in_progress tasks regardless of age" do
        old_in_progress = create(:task, :in_progress, user: user)
        old_in_progress.update_column(:updated_at, 60.days.ago)

        described_class.new.perform

        expect(Task.exists?(old_in_progress.id)).to be true
      end
    end

    context "when no tasks match the criteria" do
      it "does not raise an error when there are no tasks at all" do
        expect { described_class.new.perform }.not_to raise_error
      end

      it "does not raise an error when only recent completed tasks exist" do
        create(:task, :completed, user: user)

        expect { described_class.new.perform }.not_to raise_error
      end
    end

    context "with a mix of tasks" do
      it "only deletes old completed tasks and leaves everything else" do
        old_completed = create(:task, :completed, user: user, title: "Old Completed")
        old_completed.update_column(:updated_at, 31.days.ago)

        recent_completed = create(:task, :completed, user: user, title: "Recent Completed")
        recent_completed.update_column(:updated_at, 10.days.ago)

        old_pending = create(:task, status: "pending", user: user, title: "Old Pending")
        old_pending.update_column(:updated_at, 60.days.ago)

        described_class.new.perform

        expect(Task.exists?(old_completed.id)).to be false
        expect(Task.exists?(recent_completed.id)).to be true
        expect(Task.exists?(old_pending.id)).to be true
      end
    end
  end
end
