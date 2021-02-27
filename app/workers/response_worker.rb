# frozen_string_literal: true

class ResponseWorker
  include Sidekiq::Worker
  include ActionView::Helpers::NumberHelper
  include Discord::Mixins::UpdateOriginalMessage
  include Discord::Mixins::UserMentionable

  NUM_RESULTS = 3
  RECENCY_MULTIPLIER = 3 # weight recent playtime more heavily
  GAME_PULL_STATUS_BACKOFF = 1.second
  GAME_PULL_MESSAGE = ':video_game: Pulling Steam game data...'

  STATUS_MESSAGES = {
    steam_library: ':books: Pulling Steam library data...',
    steam_games:   GAME_PULL_MESSAGE,
    working:       ':abacus: Crunching the numbers...',
    error:         'An error occurred while pulling Steam data.'
  }.freeze

  sidekiq_options retry: false # too slow for our use case

  def perform(interaction_token, user_id_mapping)
    @interaction_token = interaction_token
    @user_id_mapping = user_id_mapping # discord user id => steam user id

    update_original_message!(status_message_content(STATUS_MESSAGES[:steam_library]))

    if invisible_library_user_ids.present?
      update_original_message!(invisible_message_content)
      return
    end

    update_original_message!(status_message_content(STATUS_MESSAGES[:steam_games]))
    matching_games

    update_original_message!(status_message_content(STATUS_MESSAGES[:working]))

    send_result_message!
  rescue StandardError
    message = status_message_content(STATUS_MESSAGES[:error], color: :uh_oh_red, footer: footer)
    update_original_message!(message)

    raise
  end

  def discord_library_mapping
    @discord_library_mapping ||= @user_id_mapping.each.with_object({}) do |(discord_user_id, steam_user_id), memo|
      memo[discord_user_id] = Steam::UserLibrary.fetch(steam_user_id)
    end
  end

  def libraries
    @libraries ||= discord_library_mapping.values
  end

  def matching_games
    return @matching_games if @matching_games

    games = {}
    next_game_status_update = Time.now + GAME_PULL_STATUS_BACKOFF
    common_game_ids.each.with_index do |game_id, idx|
      game = Steam::Game.fetch(game_id)
      next unless game.usable?

      next if interaction_data[:sort] == 'fewest-shared-achievements' && game.achievements.to_i.zero?

      next if interaction_data[:sort] == 'lowest-metascore' && game.metacritic.blank?

      games[game_id] = game
      next if Time.now < next_game_status_update

      message = status_message_content("#{GAME_PULL_MESSAGE} (#{idx + 1}/#{common_game_ids.size})")
      update_original_message!(message)
      next_game_status_update = Time.now + GAME_PULL_STATUS_BACKOFF
    end

    @matching_games = games
  end

  def common_game_ids
    @common_game_ids ||= libraries.map(&:game_ids).reduce(:&)
  end

  def send_result_message!
    results = result_content

    Redis.current.set("token-#{@interaction_token}-payload", results.to_json, ex: DELETION_TIMEOUT.to_i)

    results[:embeds].first[:footer][:text] += " | results will self-destruct in #{SOFT_DELETION_TIMEOUT.inspect}"

    response = update_original_message!(results)

    add_delete_reaction!(response)

    Redis.current.set("message-#{response['id']}-token", @interaction_token, ex: DELETION_TIMEOUT.to_i)

    schedule_auto_delete_workers!
  end

  def add_delete_reaction!(response)
    message = Discordrb::Message.new(response.to_h, DISCORD_BOT)
    message.react CROSS_MARK
  rescue Discordrb::Errors::NoPermission
    # probably invoked from a private channel that the bot can't see/react in - noop
  end

  def result_content
    embeds = if final_games.empty? # truly the saddest edge case
      word = user_ids.one? ? "doesn't" : "don't"

      [{
        description: "It seems that #{mention_phrase} #{word} have any matching games. I'm... I'm so sorry.",
        color:       DISCORD_COLORS[:sadge_grey],
        footer:      { text: footer }
      }]
    else
      [summary_embed, *final_games.map.with_index { |game, idx| game_embed(game, idx) }]
    end

    { embeds: embeds }
  end

  def final_games
    @final_games ||= matching_games.values.sort_by { |game| total_game_score(game) }.first(interaction_data[:n])
  end

  def total_game_score(game)
    case interaction_data[:sort]
    when 'most-playtime'
      -total_playtime_score(game)
    when 'least-playtime'
      total_playtime_score(game)
    when 'most-shared-achievements'
      [-shared_achievement_proportion(game), -total_playtime_score(game)]
    when 'fewest-shared-achievements'
      [shared_achievement_proportion(game), -total_playtime_score(game)]
    when 'highest-metascore'
      [-game.metascore, -total_playtime_score(game)]
    when 'lowest-metascore'
      [game.metascore, -total_playtime_score(game)]
    end
  end

  def total_playtime_score(game)
    user_ids.sum { |user_id| playtime_score(user_id, game.id) }
  end

  def playtime_score(user_id, game_id)
    stats = user_stats(user_id, game_id)

    stats[:total] + stats[:recent] * RECENCY_MULTIPLIER
  end

  def shared_achievement_proportion(game)
    return 0 if game.achievements.to_i.zero?

    mutually_unlocked_achievements(game).size / game.achievements.to_f
  end

  def mutually_unlocked_achievements(game)
    @user_id_mapping.values.map do |steam_user_id|
      Steam::UserAchievements.fetch(steam_user_id, game.id).unlocked_achievement_names
    end.reduce(:&)
  end

  def summary_embed
    result_count = final_games.one? ? 'game' : "#{final_games.size} #{'game'.pluralize final_games.size}"
    user_phrase = if user_ids.one?
      "#{mention(user_ids.first)}'s top #{result_count}"
    else
      "the top #{result_count} for #{mention_phrase(user_ids)}"
    end
    sort_name = interaction_data[:sort].tr('-', ' ')
    matching = 'matching ' if user_ids.many?
    matching_games_phrase = "#{matching_games.size} #{matching}multiplayer #{'game'.pluralize matching_games.size}"

    {
      description: "Here's #{user_phrase} by #{sort_name} (of #{matching_games_phrase}):",
      color:       DISCORD_COLORS[:yay_green],
      footer:      { text: footer }
    }
  end

  def footer
    "#{requestor_phrase} | processed in #{processing_time}"
  end

  def game_embed(game, idx)
    fields = if user_ids.one?
      total, recent = user_stats(user_ids.first, game.id).values

      [{ name: 'Total playtime', value: pretty_playtime(total), inline: true },
       { name: 'Recent playtime', value: pretty_playtime(recent), inline: true },
       { name: 'Achievements', value: achievements_value(game), inline: true },
       { name: 'Metascore', value: game.metascore_field_value, inline: true }]
    else
      multi_user_game_fields(game)
    end

    {
      title:     "##{idx + 1}. #{game.name}",
      url:       game.store_url,
      fields:    fields,
      thumbnail: { url: game.thumb_url },
      color:     DISCORD_COLORS[:yay_green]
    }
  end

  def invisible_library_user_ids
    @invisible_library_user_ids ||= discord_library_mapping.select do |_discord_user_id, library|
      library.nil?
    end.keys
  end

  def invisible_message_content
    count = invisible_library_user_ids.size
    libraries_word = 'library'.pluralize(count)
    appear_word = count == 1 ? 'appears' : 'appear'
    description = <<~DESC
      #{mention_phrase(invisible_library_user_ids)} #{appear_word} \
      to have their Steam #{libraries_word} set to "private".

      Please check your privacy settings in Steam and then try again.
    DESC

    {
      embeds: [{
        title:       "Couldn't access #{count} Steam #{libraries_word}",
        description: description,
        color:       DISCORD_COLORS[:uh_oh_red],
        footer:      { text: footer }
      }]
    }
  end

  def user_stats(user_id, game_id)
    discord_library_mapping[user_id].stats(game_id)
  end

  def pretty_playtime(mins, suffix: nil)
    return "none #{suffix}".strip if mins.nil? || mins.zero?
    return mins.minutes.inspect if mins < 60 && suffix.nil?

    suffix ||= 'hours'
    hours = (mins / 60.0).truncate(1)

    "#{number_with_delimiter(hours)} #{suffix}"
  end

  def multi_user_game_fields(game)
    total_playtime = pretty_playtime(libraries.sum { |library| library.stats(game.id)[:total] })
    score_groups = user_ids.group_by { |user_id| playtime_score(user_id, game.id) }
    min_user_playtimes, max_user_playtimes = score_groups.minmax.map do |grouping|
      grouping.last.map { |user_id| user_playtime_phrase(user_id, game.id) }.to_sentence
    end

    [{ name: 'Total playtime', value: total_playtime, inline: true },
     { name: 'Most playtime', value: max_user_playtimes, inline: true },
     { name: 'Least playtime', value: min_user_playtimes, inline: true },
     { name: 'Shared achievements', value: achievements_value(game), inline: true },
     { name: 'Metascore', value: game.metascore_field_value, inline: true }]
  end

  def achievements_value(game)
    return 'N/A' if game.achievements.to_i.zero?

    "#{(shared_achievement_proportion(game) * 100).to_i}% "\
    "(#{mutually_unlocked_achievements(game).size}/#{game.achievements})"
  end

  def user_playtime_phrase(user_id, game_id)
    stats = user_stats(user_id, game_id)
    total_hours = pretty_playtime(stats[:total])
    recent_hours = " (#{pretty_playtime(stats[:recent], suffix: 'recent')})" if stats[:total].positive?

    "#{mention(user_id)} with #{total_hours}#{recent_hours}"
  end

  def user_ids
    @user_ids ||= @user_id_mapping.keys
  end

  def schedule_auto_delete_workers!
    (1..(SOFT_DELETION_TIMEOUT.to_i / 60)).each do |n|
      Discord::AutoDeleteWorker.perform_in(n.minutes, @interaction_token)
    end
  end

  def processing_time
    ms_ttl = Redis.current.pttl(processing_key)
    ms = DELETION_TIMEOUT.to_i * 1000.0 - ms_ttl

    if ms < 1000
      "#{ms.to_i} ms"
    else
      "#{ms / 1000} sec"
    end
  end
end
