require 'rails_helper'

RSpec.describe "Tasks Background Jobs Integration", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  describe "POST /tasks" do
    context "with valid params" do
      let(:valid_params) do
        {
          task: {
            title: "New Task",
            status: "pending",
            priority: 1,
            due_date: Date.today + 7
          }
        }
      end

      it "enqueues TaskNotificationJob with task id and 'created'" do
        expect {
          post "/tasks", params: valid_params, headers: headers
        }.to have_enqueued_job(TaskNotificationJob).with { |task_id, notification_type|
          expect(notification_type).to eq("created")
          expect(Task.find(task_id).title).to eq("New Task")
        }
      end
    end

    context "with invalid params (missing title)" do
      let(:invalid_params) do
        { task: { title: "", status: "pending" } }
      end

      it "does not enqueue TaskNotificationJob" do
        expect {
          post "/tasks", params: invalid_params, headers: headers
        }.not_to have_enqueued_job(TaskNotificationJob)
      end
    end
  end

  describe "PATCH /tasks/:id" do
    context "when status changes to completed" do
      let!(:task) { create(:task, :in_progress, user: user) }

      it "enqueues TaskNotificationJob with task id and 'completed'" do
        expect {
          patch "/tasks/#{task.id}", params: { task: { status: "completed" } }, headers: headers
        }.to have_enqueued_job(TaskNotificationJob).with(task.id, "completed")
      end
    end

    context "when status changes to a non-completed value" do
      let!(:task) { create(:task, :todo, user: user) }

      it "does not enqueue TaskNotificationJob" do
        expect {
          patch "/tasks/#{task.id}", params: { task: { status: "in_progress" } }, headers: headers
        }.not_to have_enqueued_job(TaskNotificationJob)
      end
    end

    context "when updating a non-status field" do
      let!(:task) { create(:task, title: "Original Title", user: user) }

      it "does not enqueue TaskNotificationJob" do
        expect {
          patch "/tasks/#{task.id}", params: { task: { title: "Updated Title" } }, headers: headers
        }.not_to have_enqueued_job(TaskNotificationJob)
      end
    end
  end
end
