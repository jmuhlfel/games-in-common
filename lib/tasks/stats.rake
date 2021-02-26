# frozen_string_literal: true

task stats: 'statsetup'

task :statsetup do
  require 'rails/code_statistics'
  ::STATS_DIRECTORIES << ['Workers', 'app/workers']
end
