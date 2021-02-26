# frozen_string_literal: true

namespace :heroku do
  task :scale_dynos do
    day = Date.today.day
    dyno_type = if day <= 21
      'free'
    else
      'hobby'
    end

    `heroku ps:type #{dyno_type} -a games-in-common`
  end
end
