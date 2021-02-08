# frozen_string_literal: true

if Rails.env.production?
  Sidekiq.configure_client do |_config|
    Rails.application.config.after_initialize do
      Steam::WarmGameCacheWorker.perform_async
    end
  end
end
