require "rails_helper"
require "yaml"

RSpec.describe "Sidekiq Infrastructure", type: :config do
  describe "sidekiq.yml queue definitions" do
    let(:config) { YAML.load_file(Rails.root.join("config/sidekiq.yml")) }

    it "defines concurrency as 5" do
      expect(config[:concurrency]).to eq(5)
    end

    it "defines critical queue with highest priority" do
      critical_entry = config[:queues].find { |q| q.first == "critical" }
      expect(critical_entry).to eq(["critical", 3])
    end

    it "defines mailers queue with medium priority" do
      mailers_entry = config[:queues].find { |q| q.first == "mailers" }
      expect(mailers_entry).to eq(["mailers", 2])
    end

    it "defines default queue with lowest priority" do
      default_entry = config[:queues].find { |q| q.first == "default" }
      expect(default_entry).to eq(["default", 1])
    end

    it "defines exactly three queues" do
      expect(config[:queues].size).to eq(3)
    end
  end

  describe "Sidekiq initializer" do
    let(:initializer_path) { Rails.root.join("config/initializers/sidekiq.rb") }

    it "exists" do
      expect(File.exist?(initializer_path)).to be true
    end

    it "configures Redis URL for the server" do
      content = File.read(initializer_path)
      expect(content).to include('Sidekiq.configure_server')
      expect(content).to include('ENV.fetch("REDIS_URL", "redis://localhost:6379/0")')
    end

    it "configures Redis URL for the client" do
      content = File.read(initializer_path)
      expect(content).to include('Sidekiq.configure_client')
      expect(content).to include('ENV.fetch("REDIS_URL", "redis://localhost:6379/0")')
    end
  end

  describe "Active Job queue adapter" do
    it "uses the test adapter in test environment" do
      expect(Rails.application.config.active_job.queue_adapter).to eq(:test)
    end
  end

  describe "Action Mailer deliver_later_queue_name" do
    it "routes mailer jobs to the mailers queue" do
      expect(Rails.application.config.action_mailer.deliver_later_queue_name).to eq("mailers")
    end
  end

  describe "routes" do
    it "mounts Sidekiq::Web at /sidekiq" do
      expect(Rails.application.routes.routes.any? { |r|
        r.path.spec.to_s.include?("/sidekiq")
      }).to be true
    end
  end

  describe "Procfile.dev" do
    let(:procfile_path) { Rails.root.join("Procfile.dev") }
    let(:content) { File.read(procfile_path) }

    it "exists" do
      expect(File.exist?(procfile_path)).to be true
    end

    it "defines a web process" do
      expect(content).to match(/^web:/)
    end

    it "defines a worker process running sidekiq" do
      expect(content).to match(/^worker:.*sidekiq/)
    end
  end

  describe "Gemfile" do
    let(:gemfile_content) { File.read(Rails.root.join("Gemfile")) }

    it "includes the sidekiq gem" do
      expect(gemfile_content).to match(/gem\s+['"]sidekiq['"]/)
    end

    it "includes the sidekiq-cron gem" do
      expect(gemfile_content).to match(/gem\s+['"]sidekiq-cron['"]/)
    end

    it "includes the letter_opener gem in development group" do
      expect(gemfile_content).to match(/group\s+:development.*?gem\s+['"]letter_opener['"]/m)
    end
  end
end
