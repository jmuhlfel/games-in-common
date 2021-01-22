class ResponseWorker
  include Sidekiq::Worker

  BASE_INTERACTION_URL = (DISCORD_API_URL_BASE + "webhooks/#{ENV['DISCORD_APP_ID']}/").freeze
  ORIGINAL_MESSAGE_SUFFIX = '/messages/@original'.freeze

  queue_as :default

  def perform(user_ids:, interaction_token:)
    @user_ids = user_ids
    @interaction_token = interaction_token

    update_original_message! { content: 'meow' }

    
  end

  def update_original_message!(data)
    puts '-------------------------------------------------------------------------'
    puts original_message_url
    puts data
    res = HTTParty.patch(original_message_url, headers: DISCORD_API_HEADERS, body: data.to_json)
    puts '-------------------------------------------------------------------------'
    puts res.headers
    puts res.body

  def initial_response
    {
      content: 'meow'
    }
  end

  def original_message_url
    @original_message_url ||= BASE_INTERACTION_URL + @interaction_token + ORIGINAL_MESSAGE_SUFFIX
  end
end
