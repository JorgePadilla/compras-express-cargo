Rails.application.routes.draw do
  resource :session
  resource :registro, only: %i[new create], controller: "registrations"
  resources :passwords, param: :token

  resource :preferencia_tema, only: [:update], controller: "theme_preferences"
  resource :preferencia_sidebar, only: [:update], controller: "sidebar_preferences"

  # Health check for Render
  get "up" => "rails/health#show", as: :rails_health_check

  # Etiquetar (Miami labeling)
  get "etiquetar", to: "etiquetar#index"
  post "etiquetar", to: "etiquetar#create"

  resources :users, except: [:destroy]

  resources :clientes, except: [:destroy] do
    collection { get :buscar }
  end

  resources :paquetes, except: [:new] do
    member do
      get :label
      get :reimprimir_etiquetas
      delete :eliminar_de_pre_alerta
      post :mover_a_pre_alerta
    end
    collection do
      get :check_tracking
      get :search
      get :export
      get :etiquetas_combinadas
      post :bulk_print
      post :bulk_export
    end
    resources :tareas, only: [:index, :new, :create, :edit, :update, :destroy] do
      member do
        post :iniciar
        post :completar
        post :reabrir
      end
    end
    resources :reempaques, only: [:index, :new, :create, :show]
  end

  resources :sucursales, except: [:show]

  # PR-D6.a: catálogos de cobros automáticos en pre-factura.
  resources :tarifas_recolecta, only: %i[index new create edit update],
            controller: "tarifas_recolecta"
  resources :servicios_extra, only: %i[index new create edit update],
            controller: "servicios_extra"

  # PR-D2.b: catálogos admin para retención y plantillas de notas al cliente.
  resources :motivos_retencion, only: %i[index new create edit update],
            controller: "motivos_retencion"
  resources :plantillas_notas_cliente, only: %i[index new create edit update],
            controller: "plantillas_notas_cliente"

  # PR-D3.a: catálogo de proveedores con autocomplete público para el
  # form del paquete; CRUD restringido a admin (controller-level guard).
  resources :proveedores, only: %i[index new create edit update] do
    collection { get :buscar }
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
    collection do
      post :clean_empty
      get :buscar
    end
  end

  resources :pre_facturas, except: [:destroy] do
    collection { get :facturables }
    member do
      post   :confirmar
      post   :facturar
      delete :anular
    end
  end

  # PR-FAC.3c: Factura ahora maneja todo el lifecycle (borrador → confirmado
  # → emitido → pagado), reemplazando el flujo PreFactura+Venta.
  resources :facturas, except: :destroy do
    collection { get :facturables }
    member do
      post   :confirmar
      post   :emitir
      post   :registrar_pago
      delete :anular
      get    :pdf
      post   :enviar_email
    end
  end

  # PR-FAC.3: alias legacy. Redirige las URLs viejas /ventas/* a las
  # nuevas /facturas/* hasta que se purguen los enlaces externos
  # (emails antiguos, bookmarks). PR-4 lo borrará.
  get  "/ventas",        to: redirect { |_, req| "/facturas#{(req.params.any? ? "?#{req.query_string}" : "")}" }
  get  "/ventas/:id",     to: redirect("/facturas/%{id}")
  get  "/ventas/:id/edit", to: redirect("/facturas/%{id}/edit")
  get  "/ventas/:id/pdf",  to: redirect("/facturas/%{id}/pdf")

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
    resource :preferencia_tema, only: [:update], controller: "theme_preferences"
    resources :pre_alertas do
      member do
        delete :anular
        post :mover_paquete
        get  :destinos_disponibles
        delete :eliminar_paquete
        get  :paquetes_disponibles
        post :agregar_paquete
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
