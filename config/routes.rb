Rails.application.routes.draw do
  resource :session
  resource :registro, only: %i[new create], controller: "registrations"
  resources :passwords, param: :token

  # Health check for Render
  get "up" => "rails/health#show", as: :rails_health_check

  # Etiquetar (Miami labeling)
  get "etiquetar", to: "etiquetar#index"
  post "etiquetar", to: "etiquetar#create"

  resources :users, except: [:destroy]

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

  resources :cotizaciones, except: :destroy do
    member do
      post   :enviar
      post   :aceptar
      delete :rechazar
      post   :generar_proforma
      get    :pdf
      post   :enviar_email
    end
  end

  resources :proformas, except: :destroy do
    collection { get :facturables }
    member do
      post   :emitir
      delete :anular
      get    :pdf
      post   :enviar_email
    end
  end

  resources :financiamientos, only: %i[index show new create] do
    member do
      post   :pagar_cuota
      delete :cancelar
    end
  end

  resource :empresa, only: %i[show edit update]

  resources :categoria_precios, except: :destroy, path: "categorias-precio"

  resources :entregas, except: [:destroy] do
    collection { get :entregables }
    member do
      post :despachar
      post :entregar
      delete :anular
    end
  end

  resource :caja, only: [:show], controller: "caja" do
    post :apertura
    post :cierre
    get  :historial
  end
  resources :ingresos_caja, only: %i[index new create show], path: "ingresos-caja"
  resources :egresos_caja, only: %i[index new create show], path: "egresos-caja"

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
    resources :cotizaciones, only: %i[index show] do
      member do
        get  :pdf
        post :aceptar
        delete :rechazar
      end
    end
    resources :proformas, only: %i[index show] do
      member { get :pdf }
    end
    resources :financiamientos, only: %i[index show]
    resources :entregas, only: %i[index show]
  end

  root "dashboard#index"
end
