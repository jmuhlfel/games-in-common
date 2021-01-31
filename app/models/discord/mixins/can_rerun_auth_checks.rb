# frozen_string_literal: true

module Discord
  module Mixins
    module CanRerunAuthChecks
      extend ActiveSupport::Concern

      included do
        def rerun_matching_auth_checks!
          cursor = nil
          keys = Set.new

          until !cursor.nil? && cursor == '0'
            results = Redis.current.scan(cursor || 0, match: 'interaction-*')
            cursor = results.first
            keys.merge(results.last)
          end

          keys.each do |key|
            parsed_discord_user_ids = JSON.parse(Redis.current.get(key))['user_ids']
            next unless (parsed_discord_user_ids & discord_user_ids).present?

            interaction_token = key.delete_prefix('interaction-')

            yield interaction_token if block_given?

            Discord::Auth::CheckWorker.perform_async(interaction_token)
          end
        end

        def discord_user_ids
          raise NotImplementedError
        end
      end
    end
  end
end
