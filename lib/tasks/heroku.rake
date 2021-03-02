# frozen_string_literal: true

namespace :heroku do
  task :scale_dynos do
    day = Date.today.day
    dyno_type = if day <= 21
      'free'
    else
      'hobby'
    end

    puts "[heroku:scale_dynos] scaling app dynos to #{dyno_type}"

    result = `heroku ps:type #{dyno_type} -a games-in-common`

    puts "[heroku:scale_dynos] result: #{result}"
  end
end
