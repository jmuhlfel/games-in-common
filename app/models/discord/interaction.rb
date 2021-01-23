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
      started_at = Time.now.utc.iso8601(3) # include milliseconds because why not

      Discord::Auth::CheckWorker.perform_async(token, user_ids, started_at)

      (1..5).each do |n|
        Discord::Auth::CheckWorker.perform_in(n.minutes, token, user_ids, started_at)
      end
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
            title: 'Checking for authorization...',
            description: "Please wait while I ~~#{SNARK.sample}~~ check for authorization from #{mention_phrase}.",
            color: DISCORD_COLORS[:info_blue]
          }]
        }
      }
    end
  end
end
