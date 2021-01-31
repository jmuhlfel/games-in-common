# frozen_string_literal: true

module Discord
  class UserDeleteWorker
    include Sidekiq::Worker
    include Discord::Mixins::UpdateOriginalMessage
    include Discord::Mixins::UserMentionable
    include Discord::Mixins::MessageSoftDeletion

    sidekiq_options retry: false # too slow for our use case

    def perform(id_hash)
      @deleting_user_id = id_hash['user_id']
      @message_id = id_hash['message_id']

      @interaction_token = Redis.current.get("message-#{@message_id}-token")

      return if soft_deleted?

      return unless @deleting_user_id.in?(relevant_user_ids)

      soft_delete_message!("by #{mention @deleting_user_id}")
    end

    private

    def relevant_user_ids
      @relevant_user_ids ||= [interaction_data[:calling_user][:id], *interaction_data[:user_ids]].uniq
    end
  end
end
