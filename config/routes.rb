Rails.application.routes.draw do
  resource :session
  resource :registro, only: %i[new create], controller: "registrations"
  resources :passwords, param: :token

  resource :preferencia_tema, only: [:update], controller: "theme_preferences"
  resource :preferencia_sidebar, only: [:update], controller: "sidebar_preferences"
  # PR-9.c: on/off + volumen de los tonos de escaneo, por usuario.
  resource :preferencia_sonido, only: [:update], controller: "sonido_preferences"
  # PR-13.c: el supervisor cambia el PIN con el que autoriza cambios de precio.
  resource :mi_pin, only: %i[edit update], controller: "pins"

  # Health check for Render
  get "up" => "rails/health#show", as: :rails_health_check

  # Etiquetar (Miami labeling)
  get "etiquetar", to: "etiquetar#index"
  post "etiquetar", to: "etiquetar#create"
  # PR-C6.10: Miami actualiza sus datos en la MISMA hoja donde los llenó, no
  # en /paquetes. Yusef: "me mandaste a editar y yo no quiero editar mi
  # paquete... que te cargue aquí la lista, esto te lo vuelve a llenar tal
  # cual como quedó".
  patch "etiquetar/:id", to: "etiquetar#update", as: :actualizar_etiquetar
  # Sesión de etiquetado por tipo de envío: el operario elige el tipo una vez
  # al inicio (queda en session) y lo cierra al terminar el lote.
  # PR-C6.28: el supervisor de Miami quita el cobro por cambio de servicio con
  # su PIN. Va bajo /etiquetar porque es donde el digitador se da cuenta del
  # error — "es que ellos no manejan la página de paquetes".
  post "etiquetar/:id/quitar_cambio_servicio", to: "etiquetar#quitar_cambio_servicio",
       as: :quitar_cambio_servicio_etiquetar

  post   "etiquetar/sesion", to: "etiquetar#iniciar_sesion",  as: :iniciar_sesion_etiquetar
  delete "etiquetar/sesion", to: "etiquetar#finalizar_sesion", as: :finalizar_sesion_etiquetar

  # PR-6: Entrega Personal — flow separado para paquetes que llegan
  # físicamente al mostrador (sin tracking del courier). Sistema genera
  # tracking automático EP-YYYY-SUC-PROV-NNNNNN. Los paquetes resultantes
  # se ven en /paquetes (listado general), no hay listado propio.
  resources :entrega_personal, only: [ :new, :create ], path: "entrega_personal"

  resources :users, except: [:destroy]

  resources :clientes, except: [:destroy] do
    collection { get :buscar }
  end

  resources :paquetes, except: [:new] do
    member do
      # PR-10.d.3: se llamaba `label`, que era el único nombre en inglés que
      # quedaba y encima nombraba mal lo que hace — esta ruta imprime el
      # **Warehouse Receipt** (carta, con términos y condiciones), no la
      # etiqueta. Yusef los llama así y el helper ya era `warehouse_receipt_helper`.
      get :warehouse_receipt
      # La etiqueta física que se pega a la caja (Dymo 2.25×1.25). Son dos
      # documentos distintos: "la etiqueta para la caja, el Warehouse Receipt
      # para el expediente" (Yusef).
      get :etiqueta
      get :reimprimir_etiquetas
      delete :eliminar_de_pre_alerta
      post :mover_a_pre_alerta
      post :asignar_tercero
      delete :quitar_tercero
      # PR-C6.42: bajar la cantidad de cajas cuando alguna ya entró a cobro.
      # Va en /paquetes y no en /etiquetar porque el problema aparece **en
      # Honduras**, al entregar: "el sistema no va a querer entregar porque
      # decía que eran dos".
      post :bajar_cajas
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

  # PR-9.a: rutas top-level para tareas que cuelgan del CLIENTE y todavía no
  # tienen paquete (en /etiquetar el paquete no existe cuando el operario
  # escanea). Las anidadas bajo :paquetes se mantienen para /paquetes/:id/tareas.
  resources :tareas, only: [ :new, :create ] do
    member do
      post :completar
      post :reabrir
    end
  end

  # PR-9.b: franja de contexto (cliente + tareas + notas) que se carga como
  # turbo-frame en /etiquetar y /entrega_personal.
  get "panel_contexto", to: "panel_contexto#show"

  resources :sucursales, except: [:show]

  # PR-10.a: "la tabla de servicios" — precios por libra, escalones y mínimos.
  resources :servicios, only: %i[index new create edit update destroy] do
    # PR-C6.20: prender/apagar el cobro en medias libras en todas las filas de
    # un servicio. Va sobre el TipoEnvio, no sobre una tarifa — de ahí que el
    # :id sea el del servicio.
    member { patch :redondeo }
  end

  # PR-10.b: cotización de flete en vivo (JSON) para el "valor a pagar".
  get "cotizador", to: "cotizador#show"

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
    collection do
      get :buscar
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
    # PR-13.d: el supervisor autoriza un cambio sobre UNA línea. Anidado bajo el
    # item porque el alcance es por línea, no por pre-factura.
    resources :items, only: [], controller: "pre_facturas" do
      resource :autorizacion, only: [ :create ], controller: "autorizaciones"
    end
  end

  # Bitácora de lo que se autorizó — sin esto el mecanismo es solo fricción.
  resources :autorizaciones, only: [ :index ], controller: "bitacora_autorizaciones"

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

  # PR-C6.29: la tasa multiplica todo lo que se cobra en dólares y hasta ahora
  # solo se podía cambiar con un deploy. Yusef: "la tasa es FIJA, la fija un
  # admin" — por eso es un CRUD y no un job.
  resource :tasa_cambio, only: %i[show update], controller: "tasa_cambio"

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
    resources :financiamientos, only: %i[index show]
    resources :entregas, only: %i[index show]
  end

  root "dashboard#index"
end
