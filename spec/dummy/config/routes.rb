# frozen_string_literal: true

Dummy::Application.routes.draw do
  root to: 'welcome#index'
  resources :users
end
