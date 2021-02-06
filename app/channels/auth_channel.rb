# frozen_string_literal: true

class AuthChannel < ApplicationCable::Channel
  def subscribed
    stop_all_streams
    stream_from "auth_#{params[:code]}"
  end
end
