Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  # Health check for Render
  get "up" => "rails/health#show", as: :rails_health_check

  # Etiquetar (Miami labeling)
  get "etiquetar", to: "etiquetar#index"
  post "etiquetar", to: "etiquetar#create"

  resources :clientes, except: [:destroy] do
    collection { get :buscar }
  end

  resources :paquetes, except: [:new, :destroy] do
    member { get :label }
    collection do
      get :check_tracking
      get :search
    end
  end

  resources :manifiestos, except: [:destroy] do
    member do
      post :add_paquete
      delete "remove_paquete/:paquete_id", action: :remove_paquete, as: :remove_paquete
      patch :enviar
    end
  end

  # Client portal
  namespace :cuenta do
    resource :session, only: %i[new create destroy]
    root "dashboard#index"
    resources :pre_alertas do
      member { delete :anular }
    end
  end

  root "dashboard#index"
end
