class ResponseWorker
  include Sidekiq::Worker

  BASE_INTERACTION_URL = (DISCORD_API_URL_BASE + "webhooks/#{ENV['DISCORD_APP_ID']}/").freeze
  ORIGINAL_MESSAGE_SUFFIX = '/messages/@original'.freeze

  queue_as :default

  def perform(user_ids:, interaction_token:)
    puts '-------------------------------------------------------------------------'
    url = original_message_url(interaction_token)
    puts url
    puts initial_response
    res = HTTParty.patch(url, headers: DISCORD_API_HEADERS, body: initial_response.to_json)
    puts '-------------------------------------------------------------------------'
    puts res.headers
    puts res.body
  end

  def initial_response
    {
      content: 'meow'
    }
  end

  def original_message_url(token)
    BASE_INTERACTION_URL + token + ORIGINAL_MESSAGE_SUFFIX
  end
end
