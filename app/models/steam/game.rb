# frozen_string_literal: true

module Steam
  class Game
    class << self
      def fetch(game_id)
        Rails.cache.fetch("steam-game-#{game_id}", expires_in: 2.days) do
          # api call
        end
      end
    end
  end
end
