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
      render status: :unauthorized
    else
      # fresh auth request - send 'em to Discord
      redirect_to_discord_auth!
    end
  end

  private

  def check_state_and_handshake!
    return render(status: :unauthorized) unless params[:state].present? && cookies[:user_auth_state] == params[:state]
    return render(status: :bad_request) if Rails.cache.read("user-code-#{params[:code]}")

    Discord::Auth::HandshakeWorker.perform_async(params[:code])
  end

  def redirect_to_discord_auth!
    state = SecureRandom.hex

    response.set_cookie(:user_auth_state, {
      value:    state,
      expires:  5.minutes.from_now,
      secure:   Rails.env.production?,
      httponly: Rails.env.production?
    })

    uri = URI(DISCORD_AUTH_URL_BASE)
    uri.query = DISCORD_AUTH_DATA.merge(redirect_uri: authorization_url, state: state).to_query

    redirect_to uri.to_s
  end
end
