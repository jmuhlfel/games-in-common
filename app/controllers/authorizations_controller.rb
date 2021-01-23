class AuthorizationsController < ApplicationController
  def create
    puts '----------'
    puts params
    if params[:state].blank?
      # fresh auth request - send 'em to Discord
      puts '---------------------------------------------'
      puts authorization_url
      redirect_to ENV['DISCORD_AUTH_URL']
    else
      # do some stuff
      head :ok
    end
  end
end
