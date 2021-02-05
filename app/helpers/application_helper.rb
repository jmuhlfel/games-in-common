# frozen_string_literal: true

module ApplicationHelper
  def steam_game_thumb_url_groups
    game_ids = Redis.current.smembers('multiplayer-steam-game-ids').sample(100)
    remaining = 100 - game_ids.size

    if remaining.positive?
      available_game_ids = Redis.current.smembers('steam-game-ids') - game_ids
      game_ids += available_game_ids.sample(remaining)
    end

    game_urls = game_ids.shuffle.map do |game_id|
      "https://cdn.akamai.steamstatic.com/steam/apps/#{game_id}/header.jpg"
    end

    game_urls.in_groups(5).map.with_index do |group, idx|
      if idx.even? # goes left
        group + group.first(10)
      else # goes right
        group.last(10) + group
      end
    end
  end
end
