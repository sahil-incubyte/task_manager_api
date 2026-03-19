require "rails_helper"

RSpec.describe TaskNotificationJob, type: :job do
  let(:user) { create(:user) }
  let(:task) { create(:task, user: user) }

  describe "queue configuration" do
    it "is enqueued on the mailers queue" do
      expect(described_class.new.queue_name).to eq("mailers")
    end
  end

  describe "enqueuing" do
    it "enqueues with task_id and notification_type arguments" do
      expect {
        described_class.perform_later(task.id, "created")
      }.to have_enqueued_job(described_class)
        .with(task.id, "created")
        .on_queue("mailers")
    end
  end

  describe "#perform" do
    context "when notification_type is 'created'" do
      it "sends the task_created email" do
        mail_double = instance_double(ActionMailer::MessageDelivery)
        allow(TaskMailer).to receive(:task_created).with(task).and_return(mail_double)
        allow(mail_double).to receive(:deliver_now)

        described_class.new.perform(task.id, "created")

        expect(TaskMailer).to have_received(:task_created).with(task)
        expect(mail_double).to have_received(:deliver_now)
      end
    end

    context "when notification_type is 'completed'" do
      it "sends the task_completed email" do
        mail_double = instance_double(ActionMailer::MessageDelivery)
        allow(TaskMailer).to receive(:task_completed).with(task).and_return(mail_double)
        allow(mail_double).to receive(:deliver_now)

        described_class.new.perform(task.id, "completed")

        expect(TaskMailer).to have_received(:task_completed).with(task)
        expect(mail_double).to have_received(:deliver_now)
      end
    end

    context "when task does not exist" do
      it "exits gracefully without raising" do
        expect {
          described_class.new.perform(-1, "created")
        }.not_to raise_error
      end

      it "does not send any email" do
        allow(TaskMailer).to receive(:task_created)
        allow(TaskMailer).to receive(:task_completed)

        described_class.new.perform(-1, "created")

        expect(TaskMailer).not_to have_received(:task_created)
        expect(TaskMailer).not_to have_received(:task_completed)
      end
    end

    context "when notification_type is unrecognized" do
      it "exits gracefully without sending email" do
        allow(TaskMailer).to receive(:task_created)
        allow(TaskMailer).to receive(:task_completed)

        expect {
          described_class.new.perform(task.id, "unknown")
        }.not_to raise_error

        expect(TaskMailer).not_to have_received(:task_created)
        expect(TaskMailer).not_to have_received(:task_completed)
      end
    end
  end

  describe "error handling configuration" do
    it "has a rescue handler for StandardError (retry)" do
      error_classes = described_class.rescue_handlers.map(&:first)
      expect(error_classes).to include("StandardError")
    end

    it "has a rescue handler for ActiveJob::DeserializationError (discard)" do
      error_classes = described_class.rescue_handlers.map(&:first)
      expect(error_classes).to include("ActiveJob::DeserializationError")
    end
  end
end
