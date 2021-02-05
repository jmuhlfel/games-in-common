# frozen_string_literal: true

Sidekiq.configure_client do |_config|
  Rails.application.config.after_initialize do
    Steam::WarmGameCacheWorker.perform_async
  end
end
