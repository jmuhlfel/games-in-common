# frozen_string_literal: true

namespace :steam do
  task warm_game_cache: :environment do
    Steam::WarmGameCacheWorker.perform_async
  end
end
