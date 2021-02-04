# frozen_string_literal: true

module Steam
  class UserAchievements
    ACHIEVEMENTS_API_URL = 'https://api.steampowered.com/ISteamUserStats/GetPlayerAchievements/v0001'
    ACHIEVEMENTS_API_DATA = {
      key:    ENV['STEAM_API_KEY'],
      format: 'json'
    }.freeze

    class << self
      def fetch(steam_user_id, steam_game_id)
        data = Rails.cache.fetch("steam-achievements-#{steam_user_id}-#{steam_game_id}", expires_in: 4.hours) do
          data = ACHIEVEMENTS_API_DATA.merge(steamid: steam_user_id, appid: steam_game_id)
          response = HTTParty.get(ACHIEVEMENTS_API_URL, query: data)

          unless response.ok?
            next {} if response.dig('playerstats', 'error') == 'Requested app has no stats'

            raise Exceptions::SteamError, response.inspect
          end

          Array(response.dig('playerstats', 'achievements'))
            .map { |achievement| [achievement['apiname'], achievement['unlocktime']] }
            .to_h
        end

        new(data)
      end
    end

    delegate :[], :fetch, :dig, to: :@data

    def initialize(data)
      @data = data
    end

    def unlocked_achievement_names
      @unlocked_achievement_names ||= @data.select { |_name, time| time.to_i.positive? }.keys
    end
  end
end
