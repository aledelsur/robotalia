redis_config = { url: ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/0") }

Sidekiq.configure_server { |config| config.redis = redis_config }
Sidekiq.configure_client { |config| config.redis = redis_config }
