# frozen_string_literal: true

module Discord
  class PresenceWorker
    include Sidekiq::Worker
    include Discord::Mixins::CanRerunAuthChecks

    attr_reader :discord_user_ids

    def perform(discord_user_ids)
      @discord_user_ids = discord_user_ids

      discord_user_ids.each do |user_id|
        Redis.current.set("user-present-#{user_id}", true, ex: 60)
      end

      rerun_matching_auth_checks! do |matching_interaction_token|
        Redis.current.set("presence-checked-interaction-#{matching_interaction_token}", true,
                          ex: EXPIRATION_TIMEOUT.to_i)
      end
    end
  end
end
