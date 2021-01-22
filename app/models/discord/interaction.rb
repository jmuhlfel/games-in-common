# frozen_string_literal: true

module Discord
  class Interaction
    include ActiveModel::Validations
    include Discord::Mixins::UserMentionable

    attr_reader :params, :id, :token

    validates :params, :token, presence: true
    validates :user_ids, presence: true, length: { minimum: 2 }

    def initialize(params)
      @params = params
      @id = params[:id]
      @token = params[:token]
    end

    def user_ids
      @user_ids ||= Array(@params.dig(:data, :options)).select do |option|
        option['name'].starts_with? 'user'
      end.map { |option| option['value'] }
    end

    def response
      {
        type: 3, # hide the command, but show our response message
        data: {
          tts: false,
          embeds: [{
            title: "Checking for authorization to pull Steam IDs for #{mention_phrase}...",
            color: DISCORD_COLORS[:info_blue]
          }]
        }
      }
    end
  end
end
