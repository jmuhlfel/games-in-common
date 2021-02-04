# frozen_string_literal: true

DISCORD_BOT = Discordrb::Bot.new(token: ENV['DISCORD_BOT_TOKEN'])

# probably shouldn't put this kind of stuff in an initializer
# also probably shouldn't have to ingest a massive stream of data
# just to get presence info and reaction events
# blame discord for making me use websockets I guess
DISCORD_BOT.raw do |event|
  case event.type
  when :GUILD_MEMBERS_CHUNK
    user_ids =
      Array(event.data['presences'])
        .select { |data| data['status'] == 'online' }
        .map { |data| data['user']['id'] }

    Discord::PresenceWorker.perform_async(user_ids)
  when :MESSAGE_REACTION_ADD
    next unless event.data.dig('emoji', 'name') == CROSS_MARK

    Discord::UserDeleteWorker.perform_async(event.data.slice('user_id', 'message_id'))
  end
end

DISCORD_BOT.run(true) # async

at_exit do
  DISCORD_BOT.stop
end
