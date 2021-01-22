# frozen_string_literal: true

module Discord
  class Authorization
    attr_reader :user_id, :auth_token

    def initialize(user_id, auth_token)
      @user_id = user_id
      @auth_token = auth_token
    end
  end
end
