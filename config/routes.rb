Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  # Health check for Render
  get "up" => "rails/health#show", as: :rails_health_check

  resources :clientes, except: [:destroy]

  root "dashboard#index"
end
