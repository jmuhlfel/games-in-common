# frozen_string_literal: true

module Discord
  module Mixins
    module UpdateOriginalMessage
      extend ActiveSupport::Concern

      BASE_INTERACTION_URL = "#{DISCORD_API_URL_BASE}/webhooks/#{ENV['DISCORD_APP_ID']}/"
      ORIGINAL_MESSAGE_SUFFIX = '/messages/@original'

      included do
        def update_original_message!(data)
          response = HTTParty.patch(original_message_url, headers: DISCORD_JSON_HEADERS, body: data.to_json)
  
          if response.not_found? && fresh?
            # Sidekiq is so damn fast, it sometimes runs this worker
            # *before Discord receives/creates the original message*. So
            # it's possible our response message doesn't exist yet.
            # Talk about good problems to have. Try again!
            sleep(0.1)
            response = response.request.perform
  
            if response.not_found? && fresh?
              # one more try (yes this is possible)
              sleep(0.4)
              response = response.request.perform
            end
          end
  
          return response if response.ok?
  
          raise DiscordError, response.inspect
        end
  
        def original_message_url
          @original_message_url ||= BASE_INTERACTION_URL + @interaction_token + ORIGINAL_MESSAGE_SUFFIX
        end
      end
    end
  end
end
