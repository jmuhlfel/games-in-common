# frozen_string_literal: true

class AuthorizationController < ApplicationController
  DISCORD_AUTH_DATA = {
    client_id:     ENV['DISCORD_APP_ID'],
    response_type: 'code',
    scope:         'identify connections'
  }.freeze

  def index
    if params[:code].present?
      check_state_and_handshake!
    elsif params[:error] == 'access_denied'
      # user denied - cry
      @denied = true
    else
      # fresh auth request - send 'em to Discord
      redirect_to_discord_auth!
    end
  end

  private

  def check_state_and_handshake!
    if Rails.cache.read("oauth-state-#{params[:state]}")
      Discord::Auth::HandshakeWorker.perform_async(params[:code])
    else
      head :unauthorized
    end
  end

  # I'm pretty sure a 4 year old with privileged access could figure
  # out how to break this "stateful" handshake. TODO.
  def redirect_to_discord_auth!
    state = SecureRandom.hex

    Rails.cache.write("oauth-state-#{state}", true, expires_in: EXPIRATION_TIMEOUT)

    uri = URI(DISCORD_AUTH_URL_BASE)
    uri.query = DISCORD_AUTH_DATA.merge(redirect_uri: authorization_url, state: state).to_query

    redirect_to uri.to_s
  end
end
