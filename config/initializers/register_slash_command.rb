# frozen_string_literal: true

# make sure Discord has the latest configuration for our slash command

Rails.application.reloader.to_prepare do
  Discord::SlashCommands.register!
end
