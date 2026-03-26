require "rails_helper"

RSpec.describe TaskMailer, type: :mailer do
  let(:user) { create(:user) }
  let(:task) { create(:task, user: user, title: "Fix login bug", status: "pending", priority: 2, due_date: Date.new(2026, 4, 15)) }

  describe "#task_created" do
    let(:mail) { described_class.task_created(task) }

    it "sends to the task owner email" do
      expect(mail.to).to eq([ user.email ])
    end

    it "sends from the default application sender" do
      expect(mail.from).to eq([ "from@example.com" ])
    end

    it "sets subject with the task title" do
      expect(mail.subject).to eq("New Task Created: Fix login bug")
    end

    it "includes task title in the html body" do
      expect(mail.html_part.body.to_s).to include("Fix login bug")
    end

    it "includes task status in the html body" do
      expect(mail.html_part.body.to_s).to include("pending")
    end

    it "includes task priority in the html body" do
      expect(mail.html_part.body.to_s).to include("2")
    end

    it "includes task due date in the html body" do
      expect(mail.html_part.body.to_s).to include("2026-04-15")
    end

    it "includes task title in the text body" do
      expect(mail.text_part.body.to_s).to include("Fix login bug")
    end

    it "includes task status in the text body" do
      expect(mail.text_part.body.to_s).to include("pending")
    end

    it "includes task priority in the text body" do
      expect(mail.text_part.body.to_s).to include("2")
    end

    it "includes task due date in the text body" do
      expect(mail.text_part.body.to_s).to include("2026-04-15")
    end

    it "delivers successfully" do
      expect { mail.deliver_now }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end

  describe "#task_completed" do
    let(:task) { create(:task, :completed, user: user, title: "Deploy v2") }
    let(:mail) { described_class.task_completed(task) }

    it "sends to the task owner email" do
      expect(mail.to).to eq([ user.email ])
    end

    it "sends from the default application sender" do
      expect(mail.from).to eq([ "from@example.com" ])
    end

    it "sets subject with the task title" do
      expect(mail.subject).to eq("Task Completed: Deploy v2")
    end

    it "includes task title in the html body" do
      expect(mail.html_part.body.to_s).to include("Deploy v2")
    end

    it "includes completion confirmation in the html body" do
      expect(mail.html_part.body.to_s).to include("completed")
    end

    it "includes task title in the text body" do
      expect(mail.text_part.body.to_s).to include("Deploy v2")
    end

    it "includes completion confirmation in the text body" do
      expect(mail.text_part.body.to_s).to include("completed")
    end

    it "delivers successfully" do
      expect { mail.deliver_now }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end
end
