require "sidekiq"
require "sidekiq/api"

Sidekiq.configure_server do |config|
  config.redis = { url: ENV["REDIS_URL"] || "redis://localhost:6379/0" }

  config.on(:startup) do
    Rails.logger.info "Sidekiq startup - loading workers..."

    Dir[Rails.root.join("app/workers/**/*.rb")].each do |file|
      require file
      Rails.logger.info "Loaded worker file: #{file}"
    end

    Rails.logger.info "All workers loaded!"
  end

  config.error_handlers << proc do |ex, ctx_hash|
    Rails.logger.error "Sidekiq error: #{ex.message}"
    Rails.logger.error ex.backtrace.join("\n")
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV["REDIS_URL"] || "redis://localhost:6379/0" }
end
