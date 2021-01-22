# frozen_string_literal: true

module Discord
  class Interaction
    include ActiveModel::Validations

    attr_reader :params

    validates :params, :token, presence: true
    validates :user_ids, presence: true, length: { minimum: 2 }

    def initialize(params)
      @params = params
    end

    def user_ids
      @user_ids ||= Array(@params.dig(:data, :options)).select do |option|
        option['name'].starts_with? 'user'
      end.map { |option| option['value'] }
    end

    def token
      @token ||= @params[:token]
    end

    def response
      {
        type: 3, # hide the command, but show our response message
        data: {
          tts: false,
          content: "Checking for authorization from #{mention_phrase}...",
          embeds: [],
          allowed_mentions: {
            parse: []
          }
        }
      }
    end

    def mention_phrase
      user_ids.map { |id| mention(id) }.to_sentence
    end

    def mention(user_id)
      "<@#{user_id}>"
    end
  end
end
