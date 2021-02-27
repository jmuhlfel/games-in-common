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

          invalid = { id: game_id, valid: false }
          next invalid unless data['success']

          data = data['data'] # https://www.youtube.com/watch?v=bl5TUw7sUBs
          next invalid unless game_id == data['steam_appid'] # duplicate game listing

          Redis.current.sadd('steam-game-ids', game_id)

          result = data.slice('name', 'metacritic').deep_symbolize_keys

          result.merge(
            id:              game_id,
            game:            data['type'] == 'game',
            multiplayer:     data['categories'].to_a.any? { |category| category['description'] == 'Multi-player' },
            available:       !data.dig('release_date', 'coming_soon'),
            recommendations: data.dig('recommendations', 'total'),
            achievements:    data.dig('achievements', 'total'),
            valid:           true
          )
        end

        new(data).tap do |game|
          Redis.current.sadd('multiplayer-steam-game-ids', game.id) if game.usable?
        end
      end
    end

    delegate :[], :fetch, :dig, to: :@data

    %i[valid game multiplayer available].each do |sym|
      define_method "#{sym}?".to_sym do
        @data[sym]
      end
    end

    %i[id name metacritic recommendations achievements].each do |sym|
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

    def metascore
      (metacritic || {})[:score].to_i
    end

    def metascore_field_value
      metacritic.present? ? "[#{metacritic[:score]}](#{metacritic[:url]})" : 'none'
    end

    def thumb_url
      @thumb_url ||= "https://cdn.akamai.steamstatic.com/steam/apps/#{id}/header.jpg"
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
