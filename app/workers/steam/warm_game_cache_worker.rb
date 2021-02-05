# frozen_string_literal: true

module Steam
  class WarmGameCacheWorker
    include Sidekiq::Worker

    POPULAR_GAMES_URL = 'https://steamspy.com/api.php?request=top100in2weeks'

    def perform
      response = HTTParty.get(POPULAR_GAMES_URL)
      raise response.inspect unless response.ok?

      steam_ids = response.keys

      steam_ids.each do |steam_id|
        Steam::Game.fetch(steam_id.to_i)
      end

      self.class.perform_in(1.hour)
    end
  end
end
