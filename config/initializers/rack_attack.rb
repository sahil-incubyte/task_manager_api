class Rack::Attack
  # Throttle all requests by IP (300 requests per 5 minutes)
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  # Throttle login attempts by IP (5 attempts per 20 seconds)
  throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
    req.ip if req.path == "/login" && req.post?
  end

  # Throttle signup attempts by IP (3 attempts per minute)
  throttle("signups/ip", limit: 3, period: 1.minute) do |req|
    req.ip if req.path == "/signup" && req.post?
  end

  # Return rate limit headers
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    now = match_data[:epoch_time]

    headers = {
      "RateLimit-Limit" => match_data[:limit].to_s,
      "RateLimit-Remaining" => "0",
      "RateLimit-Reset" => (now + (match_data[:period] - now % match_data[:period])).to_s,
      "Content-Type" => "application/json"
    }

    [ 429, headers, [ { error: "Rate limit exceeded. Retry later." }.to_json ] ]
  end
end

# Use Redis as the cache store for Rack::Attack in production
if Rails.env.production? && ENV["REDIS_URL"].present?
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV["REDIS_URL"])
end
