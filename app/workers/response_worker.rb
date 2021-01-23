# frozen_string_literal: true

class ResponseWorker
  include Sidekiq::Worker

  def perform(interaction_token, user_id_mapping)
    @interaction_token = interaction_token
    @user_id_mapping = user_id_mapping # discord user id => steam user id

    puts '------------------------------!!!-------------------------------------'
    puts 'holy shit we actually have liftoff'
    puts @user_id_mapping
  end
end
