# frozen_string_literal: true

module Discord
  module Auth
    class HandshakeWorker
      include Sidekiq::Worker
      include Discord::Mixins::UserAuth
      include Discord::Mixins::CanRerunAuthChecks

      TOKEN_URL = "#{DISCORD_OAUTH_API_URL_BASE}/token"
      TOKEN_DATA = {
        client_id:     ENV['DISCORD_APP_ID'],
        client_secret: ENV['DISCORD_APP_SECRET'],
        grant_type:    'authorization_code',
        scope:         'identify connections'
      }.freeze

      sidekiq_options retry: false # too slow for our use case

      def perform(code)
        @code = code

        exchange_response = request_token!(@code)
        token = exchange_response['access_token']
        raise Exceptions::DiscordError, exchange_response.inspect if token.blank?

        user_response = request_discord_user!(token)
        @discord_user_id = user_response['id']
        raise Exceptions::DiscordError, user_response.inspect if @discord_user_id.blank?

        Rails.cache.write(user_token_cache_key(@discord_user_id), token, expires_in: exchange_response['expires_in'])
        Rails.cache.write("user-code-#{@code}", true, expires_in: 1.hour)

        rerun_matching_auth_checks!

        update_client!(true)
      rescue StandardError
        update_client!(false)

        raise
      end

      private

      def request_token!(code)
        data = TOKEN_DATA.merge(redirect_uri: authorization_url, code: code)

        HTTParty.post(TOKEN_URL, headers: DISCORD_FORM_HEADERS, body: data.to_query)
      end

      def request_discord_user!(token)
        HTTParty.get(USER_URL, headers: user_headers(token))
      end

      # have to try a few times because sidekiq is too fast and the subscription might not exist yet
      def update_client!(success)
        5.times do
          push_count = ActionCable.server.broadcast("auth_#{@code}", { success: success })
          return true if push_count.positive?

          sleep 0.5
        end

        false
      end

      def discord_user_ids
        @discord_user_ids ||= [@discord_user_id]
      end
    end
  end
end
