# frozen_string_literal: true

namespace :steam do
  task :warm_game_cache do
    Steam::WarmGameCacheWorker.perform_async
  end
end
