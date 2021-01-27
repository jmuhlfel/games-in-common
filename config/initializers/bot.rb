# frozen_string_literal: true

DISCORD_BOT = Discordrb::Bot.new(token: ENV['DISCORD_BOT_TOKEN'])
DISCORD_BOT.raw do |event|
  next unless event.type == :GUILD_MEMBERS_CHUNK

  puts event.inspect
  puts '-------------------------------------------'
  user_ids =
    Array(event.data['presences'])
    .select { |data| data['status'] == 'online' }
    .map { |data| data['user']['id'] }

  Discord::PresenceWorker.perform_async(user_ids)
end
DISCORD_BOT.run(true) # async

at_exit do
  DISCORD_BOT.join
end
