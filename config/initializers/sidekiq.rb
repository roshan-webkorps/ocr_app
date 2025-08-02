require "sidekiq"
require "sidekiq/api"

require_relative "../../app/workers/document_processor_worker"

require "sidekiq/rails" if defined?(Rails)

Sidekiq.configure_server do |config|
  config.redis = { url: ENV["REDIS_URL"] || "redis://localhost:6379/0" }

  config.on(:startup) do
    Rails.application.eager_load! if defined?(Rails)
  end

  config.error_handlers << proc do |ex, ctx_hash|
    Rails.logger.error "Sidekiq error: #{ex.message}"
    Rails.logger.error ex.backtrace.join("\n")
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV["REDIS_URL"] || "redis://localhost:6379/0" }
end
