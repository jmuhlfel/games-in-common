# frozen_string_literal: true

module Discord
  class Interaction
    include ActiveModel::Validations
    include Discord::Mixins::UserAuth
    include Discord::Mixins::UserMentionable

    SNARK = [
      'do my taxes',
      'grab a snack',
      'finish my 120star run',
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
          playtime, metascore, or achievement completion. Options:
            `n`: sets the number of top games to return (1 to 9)
            `sort`: sets the metric that the bot uses to rank each game
              `Most playtime` (default): show games that the group has the most time played in, weighing recent playtime more heavily
              `Least playtime`: opposite of the above, for when you feel like playing something "new"
              `Most shared achievements`: show games that have the highest proportion of shared unlocked achievements
              `Fewest shared achievments`: opposite of the above, useful for group achievement hunting (games without achievements will be filtered out)
              `Highest metascore`: show games that have the highest metascores (games without metascores default to 0)
              `Lowest metascore`: opposite of the above. Maybe useful for drinking games? (games without metascores will be filtered out)
              ~~`God-gamer`~~: The world isn't ready.

          `/gamesincommonhelp` shows this help message (just for you!).

          `/gamesincommonrevoke` immediately deletes your user access token from the bot's cache, preventing any \
          `/gamesincommon` requests that include you from working until you authorize it again. Access tokens are \
          automatically deleted anyway (generally after a week), but you can move things along if you so choose.

          Your privacy is important. Please [read the privacy policy](#{PRIVACY_POLICY_URL}) and \
          [pass along any bug reports or suggestions for improvements you might have](#{REPORTS_URL}).
        HELP
      }
    }.freeze
    TOKEN_DELETED_RESPONSE = 'Your `/gamesincommon` user access token has been deleted. The bot will be unable to see your library until you authorize again.'
    NO_TOKEN_RESPONSE = "You don't currently have a `/gamesincommon` user access token! The bot will be unable to see your library until you authorize."
    COMMANDS = %w[gamesincommon gamesincommonhelp gamesincommonrevoke].freeze
    N_VALUES = (1..9).to_a.freeze
    SORT_VALUES = %w[
      mostplaytime
      leastplaytime
      mostsharedachievements
      fewestsharedachievements
      highestmetascore
      lowestmetascore
    ].freeze

    attr_reader :params, :token

    validates :params, :token, presence: true
    validates :command, presence: true, inclusion: { in: COMMANDS }

    with_options if: :primary? do
      validates :user_ids, presence: true
      validates :n, presence: true, inclusion: { in: N_VALUES }
      validates :sort, presence: true, inclusion: { in: SORT_VALUES }
    end

    def initialize(params)
      @params = params
      @token = params[:token]
    end

    def perform!
      case command
      when 'gamesincommon'
        schedule_workers!
      when 'gamesincommonrevoke'
        @revoked = Rails.cache.delete(user_token_cache_key(calling_user[:id]))
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
      @command ||= @params.dig(:data, :name)
    end

    def primary?
      command == 'gamesincommon'
    end

    def n
      @n ||= option_values { |option| option == 'n' }.first&.to_i
    end

    def sort
      @sort ||= option_values { |option| option == 'sort' }.first
    end

    def cache_data
      {
        user_ids:     user_ids,
        guild_id:     @params[:guild_id],
        calling_user: calling_user,
        n:            n,
        sort:         sort
      }
    end

    def user_ids
      @user_ids ||= option_values { |option| option.starts_with? 'user' }.uniq
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
      when 'gamesincommonrevoke'
        revoke_response
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

    def revoke_response
      {
        type: 3,
        data: {
          tts:     false,
          flags:   64, # ephemeral
          content: @revoked ? TOKEN_DELETED_RESPONSE : NO_TOKEN_RESPONSE
        }
      }
    end

    def options
      @options ||= Array(@params.dig(:data, :options))
    end

    private

    def option_values
      options.select do |option|
        yield option[:name]
      end.map { |option| option[:value] }
    end
  end
end
