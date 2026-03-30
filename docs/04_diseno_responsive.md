# Compras Express Cargo - Diseño Responsive (Mobile-First)

## Estrategia

Diseño **mobile-first** con Tailwind CSS 4. Tres breakpoints principales:

| Breakpoint | Ancho        | Dispositivo        | Uso principal                  |
|-----------|-------------|--------------------|---------------------------------|
| Default   | < 640px     | Celular            | Clientes viendo links de pago   |
| `sm:`     | >= 640px    | Celular landscape  | -                               |
| `md:`     | >= 768px    | Tablet             | Empleados en bodega             |
| `lg:`     | >= 1024px   | Laptop/Desktop     | Admin / oficina                 |

---

## Layout Principal con Sidebar Responsive

```erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html lang="es" class="h-full">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Compras Express Cargo</title>
  <%= csrf_meta_tags %>
  <%= csp_meta_tag %>
  <%= stylesheet_link_tag "tailwind", "inter-font", "data-turbo-track": "reload" %>
  <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
  <%= javascript_importmap_tags %>
</head>
<body class="h-full bg-gray-50" data-controller="sidebar dark-mode">
  <div class="flex h-full">

    <%# ========== SIDEBAR ========== %>
    <%# Mobile: overlay con backdrop, Desktop: fijo a la izquierda %>
    <aside id="sidebar"
      class="fixed inset-y-0 left-0 z-40 w-64 bg-gray-800 text-white
             transform -translate-x-full transition-transform duration-300 ease-in-out
             lg:translate-x-0 lg:static lg:z-auto"
      data-sidebar-target="menu">

      <%# Logo %>
      <div class="p-4 border-b border-gray-700">
        <%= link_to root_path do %>
          <%= image_tag "logo_compras_express.png", class: "h-10", alt: "CEC" %>
        <% end %>
      </div>

      <%# Navegación %>
      <nav class="flex-1 overflow-y-auto py-4">
        <%= render "layouts/sidebar_nav" %>
      </nav>

      <%# Footer sidebar %>
      <div class="p-4 border-t border-gray-700">
        <%= link_to "Salir", session_path, data: { turbo_method: :delete },
            class: "flex items-center gap-2 text-red-400 hover:text-red-300 text-sm" %>
      </div>
    </aside>

    <%# Backdrop mobile %>
    <div id="sidebar-backdrop"
      class="fixed inset-0 bg-black/50 z-30 hidden lg:hidden"
      data-sidebar-target="backdrop"
      data-action="click->sidebar#close">
    </div>

    <%# ========== CONTENIDO PRINCIPAL ========== %>
    <main class="flex-1 flex flex-col min-h-screen overflow-x-hidden">

      <%# Top bar (mobile) %>
      <header class="bg-white shadow-sm px-4 py-3 flex items-center justify-between lg:hidden">
        <button data-action="click->sidebar#toggle" class="text-gray-600 p-1">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                  d="M4 6h16M4 12h16M4 18h16"/>
          </svg>
        </button>
        <span class="font-bold text-gray-800">CEC</span>
        <button data-action="click->dark-mode#toggle" class="text-gray-600 p-1">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                  d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z"/>
          </svg>
        </button>
      </header>

      <%# Contenido de la página %>
      <div class="flex-1 p-4 md:p-6 lg:p-8">
        <%# Flash messages %>
        <% if notice %>
          <div class="mb-4 p-3 bg-green-100 text-green-800 rounded-lg text-sm"><%= notice %></div>
        <% end %>
        <% if alert %>
          <div class="mb-4 p-3 bg-red-100 text-red-800 rounded-lg text-sm"><%= alert %></div>
        <% end %>

        <%= yield %>
      </div>
    </main>
  </div>
</body>
</html>
```

---

## Sidebar Navigation Partial

```erb
<%# app/views/layouts/_sidebar_nav.html.erb %>
<ul class="space-y-1 px-3">
  <%= sidebar_link "Home", root_path, icon: "home" %>
  <%= sidebar_link "Estadísticas", estadisticas_path, icon: "chart" %>
  <%= sidebar_link "Mi Día", mi_dia_path, icon: "calendar" %>

  <%= sidebar_section "Logística" do %>
    <%= sidebar_link "Etiquetar", etiquetar_paquetes_path %>
    <%= sidebar_link "Manifiestos", manifiestos_path %>
    <%= sidebar_link "Todos los Paquetes", paquetes_path %>
  <% end %>

  <%= sidebar_section "Caja" do %>
    <%= sidebar_link "Pre-Facturas", pre_facturas_paquetes_path %>
    <%= sidebar_link "Pre-Alertas", pre_alertas_paquetes_path %>
    <%= sidebar_link "Ventas", ventas_path %>
    <%= sidebar_link "Recibos", recibos_path %>
  <% end %>

  <%= sidebar_link "Clientes", clientes_path, icon: "users" %>
  <%= sidebar_link "Entregas", entregas_path, icon: "truck" %>

  <%= sidebar_section "Marketing" do %>
    <%= sidebar_link "Correos", marketing_correos_path %>
    <%= sidebar_link "WhatsApp", marketing_whatsapp_index_path %>
    <%= sidebar_link "SMS", marketing_sms_index_path %>
  <% end %>

  <%= sidebar_link "Configuraciones", configuraciones_path, icon: "settings" %>
  <%= sidebar_link "Reportes", reportes_path, icon: "file" %>
</ul>
```

---

## Stimulus Controller: Sidebar

```javascript
// app/javascript/controllers/sidebar_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "backdrop"]

  toggle() {
    this.menuTarget.classList.toggle("-translate-x-full")
    this.backdropTarget.classList.toggle("hidden")
    document.body.classList.toggle("overflow-hidden")
  }

  close() {
    this.menuTarget.classList.add("-translate-x-full")
    this.backdropTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }
}
```

---

## Tablas Responsive

Las tablas del sistema actual (paquetes, manifiestos, ventas) necesitan ser responsive. Dos estrategias:

### Estrategia 1: Scroll horizontal en mobile
```erb
<%# Para tablas con muchas columnas como Manifiestos %>
<div class="overflow-x-auto -mx-4 md:mx-0">
  <div class="inline-block min-w-full align-middle">
    <table class="min-w-full divide-y divide-gray-200">
      <thead class="bg-gray-50">
        <tr>
          <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Fecha</th>
          <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">No. Manifiesto</th>
          <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase hidden md:table-cell">Empresa</th>
          <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">Estado</th>
          <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase hidden sm:table-cell">T.E.</th>
          <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Cant.</th>
          <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase hidden md:table-cell">Peso</th>
          <th class="px-3 py-2"></th>
        </tr>
      </thead>
      <tbody class="divide-y divide-gray-200 bg-white">
        <%# Filas %>
      </tbody>
    </table>
  </div>
</div>
```

### Estrategia 2: Cards en mobile, tabla en desktop
```erb
<%# Para listas de paquetes %>

<%# Desktop: tabla %>
<div class="hidden md:block">
  <table class="min-w-full divide-y divide-gray-200">
    <%# ... tabla normal ... %>
  </table>
</div>

<%# Mobile: cards %>
<div class="md:hidden space-y-3">
  <% @paquetes.each do |paquete| %>
    <div class="bg-white rounded-lg shadow p-4">
      <div class="flex justify-between items-start mb-2">
        <div>
          <p class="font-semibold text-sm"><%= paquete.tracking %></p>
          <p class="text-xs text-gray-500"><%= paquete.cliente.nombre %></p>
        </div>
        <span class="px-2 py-1 text-xs rounded-full
          <%= paquete_estado_color(paquete.estado) %>">
          <%= paquete.estado.humanize %>
        </span>
      </div>
      <div class="flex justify-between text-sm text-gray-600">
        <span><%= paquete.peso %> lbs</span>
        <span class="font-semibold">$<%= number_with_precision(paquete.monto_total, precision: 2) %></span>
      </div>
    </div>
  <% end %>
</div>
```

---

## Dashboard Responsive (Home)

```erb
<%# app/views/dashboard/index.html.erb %>
<h1 class="text-xl md:text-2xl font-bold text-gray-800 mb-6">Dashboard</h1>

<%# Secciones como botones - Grid responsive %>
<% sections = [
  { title: "Miami", buttons: [
    { label: "Etiquetar", path: etiquetar_paquetes_path },
    { label: "Manifiesto", path: manifiestos_path },
    { label: "Clientes", path: clientes_path },
    { label: "Todos los Paquetes", path: paquetes_path }
  ]},
  { title: "Caja", buttons: [
    { label: "Pre-Facturas", path: pre_facturas_paquetes_path },
    { label: "Todos los Paquetes", path: paquetes_path },
    { label: "Pre-Alertas", path: pre_alertas_paquetes_path },
    { label: "Todas las Ventas", path: ventas_path },
    { label: "Recibos", path: recibos_path }
  ]},
  # ... más secciones
] %>

<% sections.each do |section| %>
  <div class="mb-6">
    <h2 class="text-lg font-semibold text-gray-700 mb-3"><%= section[:title] %></h2>
    <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3">
      <% section[:buttons].each do |btn| %>
        <%= link_to btn[:path],
            class: "bg-gray-800 hover:bg-gray-700 text-white text-center py-3 px-4
                   rounded-lg text-sm font-medium transition-colors" do %>
          <%= btn[:label] %>
        <% end %>
      <% end %>
    </div>
  </div>
<% end %>
```

---

## Filtros Responsive (Paquetes)

```erb
<%# Los filtros del listado de paquetes se colapsan en mobile %>
<div data-controller="filters">
  <%# Botón toggle filtros (mobile) %>
  <button data-action="click->filters#toggle"
    class="md:hidden w-full bg-white rounded-lg p-3 mb-3 flex justify-between items-center shadow-sm">
    <span class="text-sm font-medium text-gray-700">Filtros</span>
    <svg class="w-5 h-5 text-gray-400 transition-transform"
         data-filters-target="icon">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
    </svg>
  </button>

  <%# Panel de filtros %>
  <div data-filters-target="panel" class="hidden md:block">
    <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3 mb-4">
      <div>
        <label class="text-xs text-gray-500">Tipo de Envío</label>
        <%= select_tag :tipo_envio, options_for_select(["Todos"] + TipoEnvio.pluck(:nombre)),
            class: "w-full border rounded-lg px-3 py-2 text-sm" %>
      </div>
      <div>
        <label class="text-xs text-gray-500">Estado</label>
        <%= select_tag :estado, options_for_select(["Todos"] + Paquete.estados.keys),
            class: "w-full border rounded-lg px-3 py-2 text-sm" %>
      </div>
      <div>
        <label class="text-xs text-gray-500">Fecha Inicio</label>
        <%= date_field_tag :fecha_inicio, nil, class: "w-full border rounded-lg px-3 py-2 text-sm" %>
      </div>
      <div>
        <label class="text-xs text-gray-500">Fecha Fin</label>
        <%= date_field_tag :fecha_fin, nil, class: "w-full border rounded-lg px-3 py-2 text-sm" %>
      </div>
      <div>
        <label class="text-xs text-gray-500">Código Cliente</label>
        <%= text_field_tag :codigo_cliente, nil, placeholder: "CEC-001",
            class: "w-full border rounded-lg px-3 py-2 text-sm" %>
      </div>
      <div>
        <label class="text-xs text-gray-500">Nombre Cliente</label>
        <%= select_tag :cliente_id, options_for_select([["Sin Definir", ""]]),
            class: "w-full border rounded-lg px-3 py-2 text-sm" %>
      </div>
    </div>
  </div>
</div>
```

---

## Resumen de Breakpoints por Sección

| Vista              | Celular (<768px)         | Tablet (768-1024px)       | Desktop (>1024px)        |
|-------------------|--------------------------|---------------------------|--------------------------|
| Sidebar           | Overlay + hamburger      | Overlay + hamburger       | Fijo a la izquierda      |
| Dashboard         | Grid 2 cols              | Grid 3-4 cols             | Grid 5 cols              |
| Paquetes          | Cards apilados           | Tabla con cols ocultas    | Tabla completa           |
| Manifiestos       | Scroll horizontal        | Tabla con cols ocultas    | Tabla completa           |
| Filtros           | Colapsados (toggle)      | Grid 3 cols               | Grid 6 cols (una fila)   |
| Checkout (pago)   | Card centrado full-width | Card max-w-md centrado    | Card max-w-md centrado   |
| Formularios       | 1 columna                | 2 columnas                | 2-3 columnas             |
