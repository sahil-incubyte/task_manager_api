class HealthController < ApplicationController
  skip_before_action :authenticate_request, only: [ :show ]

  def show
    health = {
      status: "ok",
      timestamp: Time.current.iso8601,
      services: {
        database: check_database,
        redis: check_redis
      }
    }

    overall_status = health[:services].values.all? { |s| s[:status] == "ok" }
    health[:status] = overall_status ? "ok" : "degraded"
    status_code = overall_status ? :ok : :service_unavailable

    render json: health, status: status_code
  end

  private

  def check_database
    ActiveRecord::Base.connection.execute("SELECT 1")
    { status: "ok" }
  rescue StandardError => e
    { status: "error", message: e.message }
  end

  def check_redis
    redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
    config = RedisClient.config(url: redis_url)
    client = config.new_client
    client.call("PING")
    { status: "ok" }
  rescue StandardError => e
    { status: "error", message: e.message }
  ensure
    client&.close
  end
end
