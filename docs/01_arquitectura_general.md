# Compras Express Cargo - Arquitectura General Rails 8

## Resumen del Proyecto

Servicio de paquetería que recibe paquetes en Miami (USA) y los envía a Honduras. Replicación y mejora del sistema actual en https://cec.rsahn.com usando **Rails 8** con diseño responsive (mobile-first).

---

## Stack Tecnológico

- **Framework:** Ruby on Rails 8.0
- **Ruby:** 3.3+
- **Base de datos:** PostgreSQL 16
- **Frontend:** Hotwire (Turbo + Stimulus), CSS con Tailwind CSS 4
- **Background Jobs:** Solid Queue (Rails 8 default)
- **Cache:** Solid Cache (Rails 8 default)
- **WebSockets:** Action Cable con Solid Cable
- **Deployment:** Render.com (staging + producción)
- **Autenticación:** Rails 8 built-in Authentication Generator
- **Archivos:** Active Storage (S3 para producción)

---

## Estructura de la Aplicación

```
compras-express-cargo/
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   ├── sessions_controller.rb          # Auth (Rails 8 generator)
│   │   ├── passwords_controller.rb         # Auth (Rails 8 generator)
│   │   ├── dashboard_controller.rb         # Home/Dashboard
│   │   ├── clientes_controller.rb          # CRUD clientes
│   │   ├── paquetes_controller.rb          # CRUD paquetes + etiquetado
│   │   ├── manifiestos_controller.rb       # CRUD manifiestos
│   │   ├── ventas_controller.rb            # Ventas/facturación
│   │   ├── recibos_controller.rb           # Recibos
│   │   ├── entregas_controller.rb          # Entrega de paquetes
│   │   ├── pre_alertas_controller.rb       # Pre-alertas de paquetes
│   │   ├── pre_facturas_controller.rb      # Pre-facturas
│   │   ├── pagos_controller.rb             # Pagos online
│   │   ├── estadisticas_controller.rb      # Dashboard estadísticas
│   │   ├── configuraciones_controller.rb   # Settings del sistema
│   │   ├── reportes_controller.rb          # Reportes
│   │   └── marketing/
│   │       ├── correos_controller.rb       # Email marketing
│   │       ├── whatsapp_controller.rb      # WhatsApp messaging
│   │       └── sms_controller.rb           # SMS messaging
│   ├── models/
│   │   ├── user.rb                # Usuarios/empleados del sistema
│   │   ├── cliente.rb             # Clientes (destinatarios)
│   │   ├── paquete.rb             # Paquetes individuales
│   │   ├── manifiesto.rb          # Manifiestos de envío
│   │   ├── venta.rb               # Ventas/transacciones
│   │   ├── recibo.rb              # Recibos de pago
│   │   ├── entrega.rb             # Entregas a clientes
│   │   ├── pre_alerta.rb          # Pre-alertas
│   │   ├── pre_factura.rb         # Pre-facturas
│   │   ├── pago.rb                # Pagos
│   │   ├── categoria_precio.rb   # Categorías de precios
│   │   ├── carrier.rb             # Carriers de carga
│   │   ├── consignatario.rb       # Consignatarios
│   │   ├── lugar.rb               # Lugares logísticos
│   │   ├── empresa_manifiesto.rb  # Empresas de manifiestos
│   │   ├── nota_credito.rb        # Notas de crédito
│   │   └── configuracion.rb       # Configuraciones del sistema
│   ├── views/
│   │   ├── layouts/
│   │   │   ├── application.html.erb    # Layout principal responsive
│   │   │   └── _sidebar.html.erb       # Sidebar navigation
│   │   ├── dashboard/
│   │   ├── clientes/
│   │   ├── paquetes/
│   │   ├── manifiestos/
│   │   ├── ventas/
│   │   ├── pagos/                      # Vista de pago para clientes
│   │   └── ...
│   ├── javascript/
│   │   ├── application.js
│   │   └── controllers/               # Stimulus controllers
│   │       ├── sidebar_controller.js   # Toggle sidebar mobile
│   │       ├── dark_mode_controller.js # Modo oscuro
│   │       ├── filters_controller.js   # Filtros dinámicos
│   │       └── notifications_controller.js
│   └── assets/
│       └── stylesheets/
│           └── application.tailwind.css
├── config/
│   ├── routes.rb
│   ├── database.yml
│   └── environments/
│       ├── development.rb
│       ├── staging.rb              # Ambiente staging
│       └── production.rb
├── db/
│   ├── migrate/
│   └── seeds.rb
├── render.yaml                     # Blueprint para Render
├── Procfile                        # Para Render
└── Dockerfile                      # Rails 8 Dockerfile
```

---

## Rutas Principales (config/routes.rb)

```ruby
Rails.application.routes.draw do
  # Autenticación (Rails 8 generator)
  resource :session
  resource :password

  # Dashboard
  root "dashboard#index"
  get "dashboard", to: "dashboard#index"
  get "estadisticas", to: "estadisticas#index"
  get "mi_dia", to: "dashboard#mi_dia"

  # Clientes
  resources :clientes do
    member do
      get :estado_cuenta
      post :asignar_precios
    end
    collection do
      post :asignar_precios_masivo
    end
  end

  # Logística
  resources :paquetes do
    collection do
      get :etiquetar
      get :pre_alertas
      get :pre_facturas
      post :recibir_miami    # Recibir paquetes en Miami
    end
    member do
      patch :cambiar_estado
    end
  end

  resources :manifiestos do
    member do
      patch :enviar
      get :imprimir
    end
  end

  resources :entregas, only: [:index, :create, :show]

  # Ventas y Facturación
  resources :ventas do
    collection do
      delete :limpiar_vacias
    end
  end
  resources :recibos, only: [:index, :show, :create]

  # Pagos Online (para clientes)
  resources :pagos, only: [:new, :create, :show]

  # Marketing CRM
  namespace :marketing do
    resources :correos
    resources :whatsapp
    resources :sms
  end

  # Configuraciones
  resource :configuraciones, only: [:show, :edit, :update]
  resources :reportes, only: [:index, :show]

  # Administración
  namespace :admin do
    resources :empleados
    resources :categorias_precio
    resources :carriers
    resources :consignatarios
    resources :lugares
    resources :tipos_envio
    resources :tamanos_caja
  end
end
```

---

## Módulos Funcionales (del sitio escaneado)

### 1. Miami (Recepción)
- **Etiquetar:** Asignar etiquetas/tracking a paquetes recibidos
- **Manifiesto:** Agrupar paquetes en manifiestos para envío
- **Clientes:** Gestión de clientes
- **Todos los Paquetes:** Listado con filtros (tipo envío, estado, fechas, cliente)

### 2. Caja
- **Pre-Facturas:** Facturas pendientes de confirmar
- **Todos los Paquetes:** Vista de paquetes con info de cobro
- **Pre-Alertas:** Alertas de paquetes próximos a llegar
- **Todas las Ventas:** Historial de ventas
- **Recibos:** Recibos generados

### 3. Facturación
- **Pre-Facturas / Pre-Alertas / Paquetes / Clientes**
- Flujo: Pre-alerta → Recepción Miami → Pre-factura → Factura → Pago

### 4. Entrega
- **Entrega Paquete:** Registro de entrega al cliente final en Honduras

### 5. Marketing CRM
- **Correos / WhatsApp / SMS:** Comunicación con clientes

### 6. Configuraciones
- Tasa de cambio, carriers, categorías de precios, consignatarios, correos empresa, empleados, empresas manifiestos, lugares, notas de crédito, puntos emisión, reportes, tamaños cajas, teléfonos WhatsApp, tipos envío

---

## Flujo Principal del Negocio

```
Cliente crea Pre-Alerta (tracking de compra online)
        ↓
Paquete llega a bodega Miami → Se etiqueta
        ↓
Se agrupa en Manifiesto → Se envía a Honduras
        ↓
Se genera Pre-Factura → Se cobra al cliente
        ↓
Se genera Recibo → Se entrega paquete
```
