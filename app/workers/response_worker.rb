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
    discord_library_mapping

    update_original_message!(status_message_content(STATUS_MESSAGES[:steam_games]))
    matching_games

    update_original_message!(status_message_content(STATUS_MESSAGES[:working]))

    update_original_message!(result_content)
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

  def result_content
    {
      embeds: [summary_embed, *final_games.map.with_index { |game, idx| game_embed(game, idx) }]
    }
  end

  def final_games
    @final_games ||= matching_games.values.sort_by { |game| total_game_score(game) }.reverse.first(NUM_RESULTS)
  end

  def total_game_score(game)
    user_ids.sum { |user_id| game_score(user_id, game.id) }
  end

  def game_score(user_id, game_id)
    stats = user_stats(user_id, game_id)

    stats[:total] + stats[:recent] * RECENCY_MULTIPLIER
  end

  def summary_embed
    result_count = final_games.one? ? 'game' : "#{final_games.size} #{'game'.pluralize final_games.size}"
    user_phrase = if user_ids.one?
      "#{mention(user_ids.first)}'s top #{result_count}"
    else
      "the top #{result_count} for #{mention_phrase(user_ids)}"
    end
    matching_games_phrase = "#{matching_games.size} multiplayer #{'game'.pluralize matching_games.size}"

    {
      description: "Here's #{user_phrase} by playtime (of #{matching_games_phrase}):",
      color:       DISCORD_COLORS[:yay_green],
      footer:      { text: footer }
    }
  end

  def footer
    "#{requestor_phrase} | took #{processing_time} to process"
  end

  def game_embed(game, idx)
    fields = if user_ids.one?
      total, recent = user_stats(user_ids.first, game.id).values

      [
        { name: 'Total playtime', value: pretty_playtime(total), inline: true },
        { name: 'Recent playtime', value: pretty_playtime(recent), inline: true },
        game.metascore_field
      ].compact
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
    score_groups = user_ids.group_by { |user_id| game_score(user_id, game.id) }
    min_user_playtimes, max_user_playtimes = score_groups.minmax.map do |user_ids|
      user_ids.map { |user_id| user_playtime_phrase(user_id) }.to_sentence
    end

    [
      { name: 'Total playtime', value: total_playtime, inline: true },
      { name: 'Most playtime', value: max_user_playtimes, inline: true },
      { name: 'Least playtime', value: min_user_playtimes, inline: true }
    ]
  end

  def user_playtime_phrase(user_id)
    stats = user_stats(user_id, game.id)
    total_hours = pretty_playtime(stats[:total])
    recent_hours = pretty_playtime(stats[:recent], suffix: 'recent')

    "#{mention(user_id)} with #{total_hours} (#{recent_hours})"
  end

  def user_ids
    @user_ids ||= @user_id_mapping.keys
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
