# frozen_string_literal: true

DISCORD_API_URL_BASE = 'https://discord.com/api/v8/'
DISCORD_APP_URL = (DISCORD_API_URL_BASE + "applications/#{ENV['DISCORD_APP_ID']}").freeze
DISCORD_API_HEADERS = {
  'Authorization' => "Bot #{ENV['DISCORD_BOT_TOKEN']}",
  'Content-Type' => 'application/json'
}.freeze
