# frozen_string_literal: true

module Steam
  class Game
    GAME_API_URL = 'https://store.steampowered.com/api/appdetails'

    class << self
      def fetch(game_id)
        data = Rails.cache.fetch("steam-game-#{game_id}", expires_in: 24.hours) do
          response = HTTParty.get(GAME_API_URL, query: { appids: game_id })
          data = response[game_id.to_s]
          raise Exceptions::SteamError, response.inspect unless response.ok?

          if data['success']
            data = data['data'] # https://www.youtube.com/watch?v=bl5TUw7sUBs
            result = data.slice('name', 'header_image', 'metacritic', 'recommendations').deep_symbolize_keys

            result.merge(
              id:          game_id,
              game:        data['type'] == 'game',
              multiplayer: data['categories'].to_a.any? { |category| category['description'] == 'Multi-player' },
              available:   !data.dig('release_date', 'coming_soon'),
              valid:       true
            )
          else
            { id: game_id, valid: false }
          end
        end

        new(data)
      end
    end

    delegate :[], :fetch, :dig, to: :@data

    %i[valid game multiplayer available].each do |sym|
      define_method "#{sym}?".to_sym do
        @data[sym]
      end
    end

    %i[id name metacritic].each do |sym|
      define_method sym do
        @data[sym]
      end
    end

    def initialize(data)
      @data = data
    end

    def usable?
      valid? && game? && multiplayer? && available?
    end

    def metascore_field
      { name: 'Metascore', value: "[#{metacritic[:score]}](#{metacritic[:url]})", inline: true } if metacritic
    end

    def thumb_url
      self[:header_image]
    end

    # Support for protocol links was unfortunately removed from Discord
    # for security reasons. Consider these methods aspirational.
    def store_url
      # "steam://store/#{id}"
      "https://store.steampowered.com/app/#{id}"
    end

    def library_url
      "steam://nav/games/details/#{id}"
    end

    def run_url
      "steam://run/#{id}"
    end
  end
end
