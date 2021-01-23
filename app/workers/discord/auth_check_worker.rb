# frozen_string_literal: true

module Discord
  class AuthCheckWorker
    include Sidekiq::Worker
    include Rails.application.routes.url_helpers
    include Discord::Mixins::UserMentionable

    BASE_INTERACTION_URL = "#{DISCORD_API_URL_BASE}/webhooks/#{ENV['DISCORD_APP_ID']}/"
    ORIGINAL_MESSAGE_SUFFIX = '/messages/@original'

    PRIVACY_POLICY_URL = 'https://lolyoudidntreallythinkiwasseriousdidyou.com'

    TIMEOUT = 5.minutes

    class DiscordError < StandardError; end

    sidekiq_options lock: :while_executing, on_conflict: :reschedule, lock_args_method: ->(args) { args.first(2) }

    def perform(interaction_token, discord_user_ids, started_at)
      @interaction_token = interaction_token
      @discord_user_ids = discord_user_ids
      @started_at = Time.parse(started_at)

      return if already_processing?

      return update_original_message!(cancellation_content) if expired?

      return update_original_message!(missing_auth_content) if unauthed_user_ids.present?

      # we don't want to repeatedly check for Steam IDs
      set_processing!

      return update_original_message!(missing_steam_id_content) if steamless_user_ids.present?

      # everyone's authenticated and has a steam ID - showtime!
      ResponseWorker.perform_async(@interaction_token, user_id_mapping)
    end

    def expired?
      Time.now.utc > expires_at
    end

    def expires_at
      @expires_at ||= @started_at + TIMEOUT
    end

    def discord_auth_hash
      @discord_auth_hash ||= @discord_user_ids.each.with_object({}) do |user_id, memo|
        memo[user_id] = Rails.cache.read(user_auth_key(user_id))
      end
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

    def steamless_user_ids
      @steamless_user_ids ||= user_id_mapping.select { |_user_id, steam_id| steam_id.blank? }.keys
    end

    def fetch_steam_id(discord_user_id); end

    def missing_auth_content
      count = unauthed_user_ids.size
      description = <<~DESC
        #{mention_phrase(unauthed_user_ids)} must authorize `/gamesincommon` to pull their linked Steam #{'ID'.pluralize(count)}.

        Please [click here](#{authorization_url}) to authorize. *(#{mins_left.inspect} left | see my [privacy policy](#{PRIVACY_POLICY_URL}))*
      DESC

      {
        embeds: [{
          title: 'Authorization needed',
          description: description,
          color: DISCORD_COLORS[:info_blue]
        }]
      }
    end

    def missing_steam_id_content
      count = steamless_user_ids.size
      verb = count == 1 ? "hasn't" : "haven't"
      description = <<~DESC
        #{mention_phrase(steamless_user_ids)} #{verb} linked their Steam #{'account'.pluralize(count)}.
        Please link your account in User Settings > Connections > Steam and try again.
      DESC

      {
        embeds: [{
          title: "Missing Steam #{'account'.pluralize(count)}!",
          description: description,
          color: DISCORD_COLORS[:warn_yellow]
        }]
      }
    end

    def cancellation_content
      count = unauthed_user_ids.size
      verb = count == 1 ? 'is a' : 'are'

      {
        embeds: [{
          title: 'Request cancelled.',
          description: "#{mention_phrase(unauthed_user_ids)} #{verb} party #{'pooper'.pluralize(count)}. Sadge.",
          color: DISCORD_COLORS[:uh_oh_red]
        }]
      }
    end

    def mins_left
      ([expires_at - Time.now, 0].max / 60).ceil.minutes
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
      response = HTTParty.patch(original_message_url, headers: DISCORD_API_HEADERS, body: data.to_json)

      if response.not_found? && fresh?
        # Sidekiq is so damn good, it sometimes executes this code
        # *before Discord receives/creates the original message*. So
        # it's possible our response message doesn't exist yet.
        # Talk about good problems to have.
        sleep(0.1)
        return HTTParty.patch(original_message_url, headers: DISCORD_API_HEADERS, body: data.to_json)
      end

      return response if response.ok?

      raise DiscordError, response.inspect
    end

    def fresh?
      Time.now.utc < @started_at + 5.seconds
    end

    def original_message_url
      @original_message_url ||= BASE_INTERACTION_URL + @interaction_token + ORIGINAL_MESSAGE_SUFFIX
    end
  end
end
