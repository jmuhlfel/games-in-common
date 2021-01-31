# frozen_string_literal: true

module Discord
  module Mixins
    module MessageSoftDeletion
      extend ActiveSupport::Concern

      included do
        def soft_deleted?
          @interaction_token.nil? || !!Redis.current.get("soft-deleted-interaction-#{@interaction_token}")
        end

        def soft_delete_message!(by_whom)
          Redis.current.set("soft-deleted-interaction-#{@interaction_token}", true, ex: DELETION_TIMEOUT.to_i)

          payload = {
            embeds: [{
              title:       'Results deleted',
              description: "`/gamesincommon` results for #{mention_phrase(interaction_data[:user_ids])} deleted #{by_whom}.",
              color:       DISCORD_COLORS[:sadge_grey],
              footer:      { text: requestor_phrase }
            }]
          }

          response = update_original_message!(payload)

          message = Discordrb::Message.new(response.to_h, DISCORD_BOT)
          message.delete_own_reaction CROSS_MARK
        end
      end
    end
  end
end
