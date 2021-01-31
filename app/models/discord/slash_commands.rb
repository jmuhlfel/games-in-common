# frozen_string_literal: true

module Discord
  class SlashCommands
    COMMAND_URL_SUFFIX = '/commands'
    GLOBAL_COMMAND_URL = (DISCORD_APP_URL + COMMAND_URL_SUFFIX).freeze

    class << self
      def register!
        command_jsons.each do |command_json|
          HTTParty.post(GLOBAL_COMMAND_URL, headers: DISCORD_JSON_HEADERS, body: command_json)
        end
      end

      def register_for_guild!(guild_id)
        guild_command_url = DISCORD_APP_URL + "/guilds/#{guild_id}" + COMMAND_URL_SUFFIX

        command_jsons.each do |command_json|
          HTTParty.post(guild_command_url, headers: DISCORD_JSON_HEADERS, body: command_json)
        end
      end

      def fetch
        HTTParty.get(GLOBAL_COMMAND_URL, headers: DISCORD_JSON_HEADERS)
      end

      def command_jsons
        Dir['app/json/discord/*.json'].map do |path|
          JSON.parse(File.read(path)).to_json
        end
      end
    end
  end
end
