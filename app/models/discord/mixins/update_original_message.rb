# frozen_string_literal: true

module Discord
  module Mixins
    module UpdateOriginalMessage
      extend ActiveSupport::Concern

      BASE_INTERACTION_URL = "#{DISCORD_API_URL_BASE}/webhooks/#{ENV['DISCORD_APP_ID']}/"
      ORIGINAL_MESSAGE_SUFFIX = '/messages/@original'
      RATE_LIMIT_KEY = 'message-rate-limit'
      MUTEX = Mutex.new

      included do
        def update_original_message!(data)
          check_rate_limit!

          response = HTTParty.patch(original_message_url, headers: DISCORD_JSON_HEADERS, body: data.to_json)

          # Sidekiq is so damn fast, it sometimes runs the worker
          # *before Discord receives/creates the original message*. So
          # it's possible our response message doesn't exist yet.
          # Talk about good problems to have. Try again!
          if response.not_found? && fresh?
            sleep(0.1)
            response = response.request.perform

            if response.not_found? && fresh?
              # one more try (yes this is possible)
              sleep(0.4)
              response = response.request.perform
            end
          elsif response.too_many_requests? # rate limit backoff
            sleep(response['retry_after'])
            response = response.request.perform
          end

          update_rate_limit!(response)

          return response if response.ok?

          raise Exceptions::DiscordError, response.inspect
        end

        def original_message_url
          @original_message_url ||= BASE_INTERACTION_URL + @interaction_token + ORIGINAL_MESSAGE_SUFFIX
        end

        def fresh?
          Time.now.utc < started_at + 5.seconds
        end

        def started_at
          @started_at ||= Time.now.utc - elapsed_seconds
        end

        def elapsed_seconds
          ms_ttl = Redis.current.pttl("interaction-#{@interaction_token}")
          # could be -1 (error) but that's fine for our use

          (DELETION_TIMEOUT.to_i * 1000.0 - ms_ttl) / 1000
        end

        def requestor_phrase
          requesting_user = interaction_data.dig(:calling_user, :username)
          requesting_user = "@#{requesting_user}" if requesting_user.present?

          "requested by #{requesting_user || 'unknown'}"
        end

        def status_message_content(title, color: :info_blue, footer: nil)
          embed = {
            title: title,
            color: DISCORD_COLORS[color]
          }
          embed.merge!(footer: { text: footer }) if footer

          { embeds: [embed] }
        end

        def interaction_data
          @interaction_data ||= JSON.parse(Redis.current.get("interaction-#{@interaction_token}")).deep_symbolize_keys
        end

        def processing_key
          @processing_key ||= "processing-interaction-#{@interaction_token}"
        end

        def check_rate_limit!
          MUTEX.synchronize do
            remaining = Redis.current.get(RATE_LIMIT_KEY)
            return if remaining.nil?

            remaining = remaining.to_i

            if remaining.positive?
              Redis.current.set(RATE_LIMIT_KEY, remaining - 1, xx: true, keepttl: true)
            else
              ttl_ms = Redis.current.pttl(RATE_LIMIT_KEY)
              sleep(ttl_ms / 1000.0)
            end
          end
        end

        def update_rate_limit!(response)
          ttl_ms = (response.headers['x-ratelimit-reset-after'].first.to_f * 1000).to_i
          return unless ttl_ms.positive?

          remaining = response.headers['x-ratelimit-remaining'].first.to_i

          Redis.current.set(RATE_LIMIT_KEY, remaining, px: ttl_ms)
        end
      end
    end
  end
end
