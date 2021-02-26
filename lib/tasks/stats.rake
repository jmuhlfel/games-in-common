# frozen_string_literal: true

task stats: 'todolist:statsetup'

namespace :todolist do
  task :statsetup do
    require 'rails/code_statistics'
    ::STATS_DIRECTORIES << ['Workers', 'app/workers']
  end
end
