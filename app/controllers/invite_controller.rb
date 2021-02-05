# frozen_string_literal: true

class InviteController < ActionController::API
  DISCORD_INVITE_AUTH_QUERY = {
    client_id:   ENV['DISCORD_APP_ID'],
    permissions: 65_600, # read message history & add reactions
    scope:       'bot applications.commands'
  }.to_query.freeze

  uri = URI(DISCORD_AUTH_URL_BASE)
  uri.query = DISCORD_INVITE_AUTH_QUERY
  DISCORD_INVITE_URL = uri.to_s.freeze

  def index
    redirect_to DISCORD_INVITE_URL
  end
end
