# frozen_string_literal: true

module Discord
  class AutoDeleteWorker
    include Sidekiq::Worker
    include Discord::Mixins::UpdateOriginalMessage
    include Discord::Mixins::UserMentionable
    include Discord::Mixins::MessageSoftDeletion

    AUTO_DELETE_TEXT = "automatically after #{SOFT_DELETION_TIMEOUT.inspect}"

    sidekiq_options retry: false # too slow for our use case

    def perform(interaction_token)
      @interaction_token = interaction_token

      return if soft_deleted?

      if auto_soft_delete?
        soft_delete_message!(AUTO_DELETE_TEXT)
      else
        payload = JSON.parse(Redis.current.get("token-#{@interaction_token}-payload")).deep_symbolize_keys
        payload[:embeds].first[:footer][:text] += " | results will self-destruct in #{mins_left.inspect}"

        update_original_message!(payload)
      end
    end

    private

    def auto_soft_delete?
      Time.now.utc > auto_soft_deletes_at
    end

    def mins_left
      ([auto_soft_deletes_at - Time.now.utc, 0].max / 60).ceil.minutes
    end

    def auto_soft_deletes_at
      @auto_soft_deletes_at ||= started_at + SOFT_DELETION_TIMEOUT
    end
  end
end
