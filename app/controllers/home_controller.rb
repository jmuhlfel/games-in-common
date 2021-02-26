# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    redirect_to REPO_URL
  end
end
