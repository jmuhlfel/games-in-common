# frozen_string_literal: true

Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  get 'invite', to: 'invite#index', as: :invite

  get 'authorize', to: 'authorization#index', as: :authorization

  resource :interactions, only: %i[create]
end
