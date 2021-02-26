# frozen_string_literal: true

DISCORD_API_URL_BASE = 'https://discord.com/api/v8'
DISCORD_APP_URL = (DISCORD_API_URL_BASE + "/applications/#{ENV['DISCORD_APP_ID']}").freeze
DISCORD_OAUTH_API_URL_BASE = 'https://discord.com/api/oauth2'
DISCORD_AUTH_URL_BASE = "#{DISCORD_OAUTH_API_URL_BASE}/authorize"
DISCORD_JSON_HEADERS = {
  'Authorization' => "Bot #{ENV['DISCORD_BOT_TOKEN']}",
  'Content-Type'  => 'application/json'
}.freeze
DISCORD_FORM_HEADERS = { 'Content-Type' => 'application/x-www-form-urlencoded' }.freeze
DISCORD_COLORS = {
  yay_green:   5_874_944,
  info_blue:   4_886_754,
  warn_yellow: 16_312_092,
  uh_oh_red:   13_632_027,
  sadge_grey:  10_197_915
}.freeze

REPO_URL = 'https://github.com/jmuhlfel/games-in-common'
PRIVACY_POLICY_URL = "#{REPO_URL}#privacy--use-of-data"
REPORTS_URL = "#{REPO_URL}/issues/new"

EXPIRATION_TIMEOUT = 5.minutes
SOFT_DELETION_TIMEOUT = 10.minutes
DELETION_TIMEOUT = 15.minutes # discord revokes tokens after this much time

CROSS_MARK = "\u274c"
