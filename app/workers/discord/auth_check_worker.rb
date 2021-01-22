# frozen_string_literal: true

module Discord
  class AuthCheckWorker
    include Sidekiq::Worker
    include Discord::Mixins::UserMentionable

    BASE_INTERACTION_URL = (DISCORD_API_URL_BASE + "webhooks/#{ENV['DISCORD_APP_ID']}/").freeze
    ORIGINAL_MESSAGE_SUFFIX = '/messages/@original'

    sidekiq_options lock: :while_executing, on_conflict: :reschedule

    def perform(interaction_token, discord_user_ids)
      @interaction_token = interaction_token
      @discord_user_ids = discord_user_ids

      return if already_processing?

      return update_original_message(missing_auth_content) if unauthed_user_ids.present?

      return update_original_message(missing_steam_id_content) if user_id_mapping.values.any?(&:blank?)

      # everyone's authenticated and has a steam ID - showtime!
      ResponseWorker.perform_async(@interaction_token, user_id_mapping)
      set_processing!
    end

    def discord_auth_hash
      @discord_auth_hash ||= Rails.cache.read_multi(@discord_user_ids.map do |user_id|
        user_auth_key(user_id)
      end)
    end

    # discord user id => steam user id
    def user_id_mapping
      @user_id_mapping ||= @discord_user_ids.each.with_object({}) do |user_id, memo|
        memo[user_id] = fetch_steam_id(user_id)
      end
    end

    def unauthed_user_ids
      @unauthed_user_ids ||= discord_auth_hash.select { |_user_id, token| token.blank? }.keys
    end

    def fetch_steam_id(discord_user_id); end

    def missing_auth_content
      {
        embed: {
          title: "Missing authorizations for #{mention_phrase(unauthed_user_ids)}",
          description: "[Click here](https://discordapp.com) to authorize\nview the [privacy policy](https://discordapp.com)",
          color: DISCORD_COLORS[:info_blue]
        }
      }
    end

    def already_processing?
      !!Rails.cache.read(processing_key)
    end

    def set_processing!
      Rails.cache.write(processing_key, true, expires_in: 15.minutes)
    end

    def processing_key
      @processing_key ||= "interaction-#{@interaction_token}-processing"
    end

    def user_auth_key(discord_user_id)
      "user-#{discord_user_id}-auth-token"
    end

    def update_original_message!(data)
      puts '-------------------------------------------------------------------------'
      puts original_message_url
      puts data
      res = HTTParty.patch(original_message_url, headers: DISCORD_API_HEADERS, body: data.to_json)
      puts '-------------------------------------------------------------------------'
      puts res.headers
      puts res.body
    end

    def original_message_url
      @original_message_url ||= BASE_INTERACTION_URL + @interaction_token + ORIGINAL_MESSAGE_SUFFIX
    end
  end
end
