# frozen_string_literal: true

module Steam
  class UserLibrary
    LIBRARY_API_URL = 'https://api.steampowered.com/IPlayerService/GetOwnedGames/v0001'
    LIBRARY_API_DATA = {
      key:    ENV['STEAM_API_KEY'],
      format: 'json'
    }.freeze
    NO_STATS = { total: 0, recent: 0 }.freeze

    class << self
      def fetch(steam_user_id)
        data = Rails.cache.fetch("steam-library-#{steam_user_id}", expires_in: 4.hours) do
          data = LIBRARY_API_DATA.merge(steamid: steam_user_id)
          response = HTTParty.get(LIBRARY_API_URL, query: data)
          raise Exceptions::SteamError, response.inspect unless response.ok?

          response = response['response'] # plz respond

          {
            total_count: response['game_count'],
            games:       response['games'].map { |game| data_from_game(game) }.to_h
          }
        end

        new(data)
      end

      def data_from_game(game)
        stats = { total: game['playtime_forever'] }
        stats[:recent] = game['playtime_2weeks'] if game['playtime_2weeks'].present?

        [game['appid'], stats]
      end
    end

    delegate :[], :fetch, :dig, to: :@data

    def initialize(data)
      @data = data
    end

    # always returns an int for both total and recent playtime
    def stats(game_id)
      dig(:games, game_id)&.reverse_merge(NO_STATS) || NO_STATS
    end

    def game_ids
      self[:games].keys
    end
  end
end
