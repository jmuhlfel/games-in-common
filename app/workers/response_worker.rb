# frozen_string_literal: true

class ResponseWorker
  include Sidekiq::Worker
  include Discord::Mixins::UpdateOriginalMessage

  STATUS_MESSAGES = {
    steam_library: 'Pulling Steam library data...'
  }.freeze

  sidekiq_options retry: false # too slow for our use case

  def perform(interaction_token, user_id_mapping)
    @interaction_token = interaction_token
    @user_id_mapping = user_id_mapping # discord user id => steam user id

    update_original_message!(status_message_content(:steam_library))
  end

  def status_message_content(type)
    {
      embeds: [{
        title: STATUS_MESSAGES[type],
        color: DISCORD_COLORS[:info_blue]
      }]
    }
  end
end
