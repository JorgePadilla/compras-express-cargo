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

  resources :pre_alertas, except: %i[destroy] do
    member { delete :anular }
    collection { post :clean_empty }
  end

  resources :pre_facturas, except: [:destroy] do
    collection { get :facturables }
    member do
      post   :confirmar
      post   :facturar
      delete :anular
    end
  end

  resources :ventas, except: %i[new create destroy] do
    member do
      post   :registrar_pago
      delete :anular
      get    :pdf
      post   :enviar_email
    end
  end

  resources :recibos, only: %i[index show] do
    member { get :pdf }
  end

  resources :notas_debito, except: :destroy do
    member do
      post   :emitir
      delete :anular
      get    :pdf
      post   :enviar_email
    end
  end

  resources :notas_credito, except: :destroy do
    member do
      post   :emitir
      delete :anular
      get    :pdf
      post   :enviar_email
    end
  end

  resource :empresa, only: %i[show edit update]

  resources :categoria_precios, except: :destroy, path: "categorias-precio"

  # Client portal
  namespace :cuenta do
    root "dashboard#index"
    resources :pre_alertas do
      member do
        delete :anular
        post :mover_paquete
        get  :destinos_disponibles
      end
    end
    resources :facturas, only: %i[index show] do
      member { get :pdf }
    end
    resources :recibos,  only: %i[index show] do
      member { get :pdf }
    end
    resources :notas_debito,  only: %i[index show] do
      member { get :pdf }
    end
    resources :notas_credito, only: %i[index show] do
      member { get :pdf }
    end
  end

  root "dashboard#index"
end
