class SlashCommand

  BASE_URL = "https://discord.com/api/v8/applications/#{ENV["DISCORD_APP_ID"]}".freeze
  URL_SUFFIX = "/commands".freeze
  GLOBAL_COMMAND_URL = (BASE_URL + URL_SUFFIX).freeze
  HEADERS = {
    "Authorization" => "Bot #{ENV["DISCORD_BOT_TOKEN"]}",
    "Content-Type" => "application/json"
  }.freeze

  class << self

    def register!
      HTTParty.post(GLOBAL_COMMAND_URL, headers: HEADERS, body: command_json)
    end

    def register_for_guild!(guild_id)
      guild_command_url = BASE_URL + "/guilds/#{guild_id}" + URL_SUFFIX

      HTTParty.post(guild_command_url, headers: HEADERS, body: command_json)
    end

    def fetch
      HTTParty.get(GLOBAL_COMMAND_URL, headers: HEADERS)
    end

    def command_json
      JSON.parse(File.read("app/json/slash_command.json")).to_json
    end

  end

end