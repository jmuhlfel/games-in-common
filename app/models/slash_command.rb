class SlashCommand

  COMMAND_URL = "https://discord.com/api/v8/applications/#{ENV["DISCORD_APP_ID"]}/commands".freeze

  def self.register!
    headers = {
      "Authorization" => "Bot #{ENV["DISCORD_BOT_TOKEN"]}",
      "Content-Type" => "application/json"
    }
    command_json = JSON.parse(File.read("app/json/slash_command.json")).to_json

    HTTParty.post(COMMAND_URL,
      headers: headers,
      body: command_json
    )
  end

end