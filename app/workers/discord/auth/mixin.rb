# frozen_string_literal: true

module Discord
  module Auth
    module Mixin
      extend ActiveSupport::Concern
      include Rails.application.routes.url_helpers

      USER_URL = "#{DISCORD_API_URL_BASE}/users/@me"

      class DiscordError < StandardError; end

      included do
        def user_headers(token)
          { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' }
        end

        def user_token_cache_key(discord_user_id)
          "user-#{discord_user_id}-token"
        end
      end
    end
  end
end
