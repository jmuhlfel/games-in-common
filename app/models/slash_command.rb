class SlashCommand
  COMMAND_URL_SUFFIX = '/commands'.freeze
  GLOBAL_COMMAND_URL = (DISCORD_APP_URL + COMMAND_URL_SUFFIX).freeze

  class << self
    def register!
      HTTParty.post(GLOBAL_COMMAND_URL, headers: DISCORD_API_HEADERS, body: command_json)
    end

    def register_for_guild!(guild_id)
      guild_command_url = DISCORD_APP_URL + "/guilds/#{guild_id}" + COMMAND_URL_SUFFIX

      HTTParty.post(guild_command_url, headers: DISCORD_API_HEADERS, body: command_json)
    end

    def fetch
      HTTParty.get(GLOBAL_COMMAND_URL, headers: DISCORD_API_HEADERS)
    end

    def command_json
      JSON.parse(File.read('app/json/slash_command.json')).to_json
    end
  end
end
