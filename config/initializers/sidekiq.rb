require "sidekiq"
require "sidekiq/api"

Dir[Rails.root.join("app/workers/**/*.rb")].each { |f| require f }

require "sidekiq/rails" if defined?(Rails)

Sidekiq.configure_server do |config|
  config.redis = { url: ENV["REDIS_URL"] || "redis://localhost:6379/0" }

  config.error_handlers << proc do |ex, ctx_hash|
    Rails.logger.error "Sidekiq error: #{ex.message}"
    Rails.logger.error ex.backtrace.join("\n")
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV["REDIS_URL"] || "redis://localhost:6379/0" }
end
