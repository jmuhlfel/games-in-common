# frozen_string_literal: true

module Discord
  module Auth
    class CheckWorker
      include Sidekiq::Worker
      include Discord::Mixins::UpdateOriginalMessage
      include Discord::Mixins::UserAuth
      include Discord::Mixins::UserMentionable

      CONNECTIONS_URL = "#{USER_URL}/connections"

      PRIVACY_POLICY_URL = 'https://lolyoudidntreallythinkiwasseriousdidyou.com'

      AUTH_ERROR_TEXT = '*(authorization timed out or declined)*'
      STEAM_ERROR_TEXT = '*(no linked Steam account)*'

      sidekiq_options lock:        :while_executing,
                      on_conflict: :reschedule,
                      retry:       false # too slow for our use case

      def perform(interaction_token)
        @interaction_token = interaction_token

        return if already_processing?

        if expired?
          update_original_message!(cancellation_content) unless deleted?
          return
        end

        return update_original_message!(missing_auth_content) if unauthed_user_ids.present?

        return update_original_message!(missing_steam_id_content) if steamless_user_ids.present?

        # everyone's authenticated and has a steam ID - showtime!
        set_processing!
        ResponseWorker.perform_async(@interaction_token, user_steam_id_mapping)
      rescue StandardError
        error_message = status_message_content('A server error occurred. Whoops.',
                                               color: :uh_oh_red, footer: requestor_phrase)
        update_original_message!(error_message)

        raise
      end

      def unauthed_user_ids
        @unauthed_user_ids ||= user_token_mapping.select { |_user_id, token| token.nil? }.keys
      end

      def steamless_user_ids
        @steamless_user_ids ||= user_steam_id_mapping.select { |_user_id, steam_id| steam_id.nil? }.keys
      end

      # discord user id => auth token
      def user_token_mapping
        @user_token_mapping ||= interaction_data[:user_ids].each.with_object({}) do |user_id, memo|
          memo[user_id] = Rails.cache.read(user_token_cache_key(user_id))
        end
      end

      # discord user id => steam id
      def user_steam_id_mapping
        @user_steam_id_mapping ||= interaction_data[:user_ids].each.with_object({}) do |user_id, memo|
          memo[user_id] = fetch_user_steam_id(user_id)
        end
      end

      def fetch_user_steam_id(discord_user_id)
        headers = user_headers(user_token_mapping[discord_user_id])
        response = HTTParty.get(CONNECTIONS_URL, headers: headers)

        response.to_a.find { |connection| connection['type'] == 'steam' }.try(:[], 'id')
      end

      def missing_auth_content
        count = unauthed_user_ids.size
        description = <<~DESC
          #{mention_phrase(unauthed_user_ids)} must authorize `/gamesincommon` to pull their linked Steam #{'ID'.pluralize(count)}.

          Please [click here](#{authorization_url}) to authorize. #{timer_privacy_blurb}
        DESC

        {
          embeds: [{
            title:       'Authorization needed',
            description: description,
            color:       DISCORD_COLORS[:info_blue]
          }]
        }
      end

      def missing_steam_id_content
        count = steamless_user_ids.size
        verb = count == 1 ? "hasn't" : "haven't"
        description = <<~DESC
          #{mention_phrase(steamless_user_ids)} #{verb} linked their Steam #{'account'.pluralize(count)}.

          Please link your account in User Settings > Connections > Steam. #{timer_privacy_blurb}
        DESC

        {
          embeds: [{
            title:       "Missing Steam #{'account'.pluralize(count)}!",
            description: description,
            color:       DISCORD_COLORS[:warn_yellow]
          }]
        }
      end

      def cancellation_content
        problem_user_ids = unauthed_user_ids.presence || steamless_user_ids
        count = problem_user_ids.size
        verb = count == 1 ? 'is a' : 'are'
        error_text = unauthed_user_ids.present? ? AUTH_ERROR_TEXT : STEAM_ERROR_TEXT
        description = <<~DESC
          #{mention_phrase(problem_user_ids)} #{verb} party #{'pooper'.pluralize(count)}. Sadge.

          #{error_text}
        DESC

        {
          embeds: [{
            title:       'Request cancelled.',
            description: description,
            color:       DISCORD_COLORS[:uh_oh_red]
          }]
        }
      end

      def timer_privacy_blurb
        "*(#{mins_left.inspect} left | see my [privacy policy](#{PRIVACY_POLICY_URL}))*"
      end

      def expired?
        Time.now.utc > expires_at && !already_processing?
      end

      def deleted?
        Time.now.utc > started_at + DELETION_TIMEOUT
      end

      def mins_left
        ([expires_at - Time.now, 0].max / 60).ceil.minutes
      end

      def expires_at
        @expires_at ||= started_at + EXPIRATION_TIMEOUT
      end

      def already_processing?
        !!Redis.current.get(processing_key)
      end

      def set_processing!
        Redis.current.set(processing_key, true, ex: DELETION_TIMEOUT.to_i)
      end
    end
  end
end
