# frozen_string_literal: true

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'], driver: :hiredis }

  config.server_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Server
  end

  config.error_handlers << ->(ex, ctx_hash) { p ex, ctx_hash }
  config.death_handlers << lambda do |job, _ex|
    digest = job['lock_digest']
    SidekiqUniqueJobs::Digests.new.delete_by_digest(digest) if digest
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'], driver: :hiredis }

  config.client_middleware do |chain|
    chain.add SidekiqUniqueJobs::Middleware::Client
  end
end
