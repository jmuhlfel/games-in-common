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
    HELP_RESPONSE = {
      type: 3,
      data: {
        tts:     false,
        flags:   64, # ephemeral
        content: <<~HELP
          `/gamesincommon` is a bot command that uses the Discord and Steam APIs to find all the multiplayer games \
          that you and your buddies (or any group of Discord users, really) own, and suggests a few based on \
          playtime, metascore, or achievement completion.
            options:
              `n`: sets the number of top games to return (1 to 10)
              `sort`: sets the metric that the bot uses to rank each game
                playtime (default): show games that the group has the most time played in, weighing recent playtime more heavily
                ratings: show games that have the highest metascores (games without metascores default to 0)
                achievements: show games that have the highest proportion of achievements that the entire group doesn't have
                ~~godgamer~~: The world isn't ready.

          `/gamesincommonhelp` shows this help message (just for you!).

          `/gamesincommonrevoke` immediately deletes your cached user access token on the bot's server, preventing any \
          `/gamesincommon` requests that include you from working until you authorize it again. This happens automatically \
          anyway (generally after a week), but you can move things along if you so choose.

          User privacy is important. Please [read the privacy policy](#{PRIVACY_POLICY_URL}) and \
          [pass along any suggestions for improvements you might have](https://google.com).
        HELP
      }
    }.freeze

    attr_reader :params, :token

    validates :params, :token, presence: true
    validates :user_ids, presence: true, if: :primary?

    def initialize(params)
      @params = params
      @token = params[:token]
    end

    def perform!
      case command
      when 'gamesincommon'
        schedule_workers!
      end
    end

    def schedule_workers!
      Redis.current.set("interaction-#{@token}", cache_data.to_json, ex: DELETION_TIMEOUT.to_i)

      Discord::Auth::CheckWorker.perform_async(token)

      (1..10).each do |n|
        Discord::Auth::CheckWorker.perform_in(30.seconds * n, token)
      end
    end

    def command
      @command ||= @params.dig('data', 'name')
    end

    def primary?
      command == 'gamesincommon'
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
      case command
      when 'gamesincommon'
        main_response
      when 'gamesincommonhelp'
        HELP_RESPONSE
      else
        raise ArgumentError
      end
    end

    def main_response
      {
        type: 3, # hide the command, but show our response message
        data: {
          tts:    false,
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
