# frozen_string_literal: true

module Discord
  class Interaction
    include ActiveModel::Validations
    include Discord::Mixins::UserMentionable

    SNARK = [
      'finish my 120star run',
      'do my taxes',
      'eat a PB&J',
      'laugh at @MOONMOON for dying again'
    ].freeze

    attr_reader :params, :token

    validates :params, :token, :user_ids, presence: true

    def initialize(params)
      @params = params
      @token = params[:token]
    end

    def schedule_workers!
      Redis.current.set("interaction-#{@token}", cache_data.to_json, ex: DELETION_TIMEOUT.to_i)

      Discord::Auth::CheckWorker.perform_async(token)

      (1..10).each do |n|
        Discord::Auth::CheckWorker.perform_in(30.seconds * n, token)
      end
    end

    def cache_data
      {
        user_ids:     user_ids,
        guild_id:     @params[:guild_id],
        calling_user: calling_user
      }
    end

    def user_ids
      @user_ids ||= Array(@params.dig(:data, :options)).select do |option|
        option['name'].starts_with? 'user'
      end.map { |option| option['value'] }.uniq
    end

    def calling_user
      @calling_user ||= (@params.dig(:member, :user) || ActionController::Parameters.new).permit(:id, :username).slice(
        :id, :username
      ).to_h
    end

    def response
      {
        type: 3, # hide the command, but show our response message
        data: {
          tts:    false,
          # flags:  64, # ephemeral
          embeds: [{
            title:       'Checking for authorization...',
            description: "Please wait while I ~~#{SNARK.sample}~~ check for authorization from #{mention_phrase}.",
            color:       DISCORD_COLORS[:info_blue]
          }]
        }
      }
    end
  end
end
