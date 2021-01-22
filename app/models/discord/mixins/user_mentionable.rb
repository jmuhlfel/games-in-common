# frozen_string_literal: true

module Discord
  module Mixins
    module UserMentionable
      extend ActiveSupport::Concern

      included do
        def mention_phrase(discord_user_ids = user_ids)
          discord_user_ids.map { |id| mention(id) }.to_sentence
        end

        def mention(user_id)
          "<@#{user_id}>"
        end
      end
    end
  end
end
