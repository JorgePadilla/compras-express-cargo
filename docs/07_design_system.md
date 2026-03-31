# CEC — Design System

## Brand Identity (del sistema actual)

**Logo:** "Compras Express" con icono de persona corriendo en rojo.
- "Compras" en rojo/marron oscuro
- "Express" en azul cursiva
- Icono runner en rojo

**Archivo:** `app/assets/images/logo_compras_express.png` (extraer del sistema actual)

---

## Paleta de Colores

### Colores Primarios (extraidos del sistema actual)

| Rol | Color | Hex | RGB | Tailwind |
|-----|-------|-----|-----|----------|
| **Primary (sidebar, botones)** | Azul marino oscuro | `#262B40` | `rgb(38, 43, 64)` | `slate-800` custom |
| **Accent (CTAs secundarios)** | Dorado/Amber | `#F5B759` | `rgb(245, 183, 89)` | `amber-400` |
| **Accent hover** | Dorado claro | `#F8BD7A` | `rgb(248, 189, 122)` | `amber-300` |
| **Success** | Verde esmeralda | `#05A677` | `rgb(5, 166, 119)` | `emerald-600` |
| **Danger** | Rojo coral | `#FA5252` | `rgb(250, 82, 82)` | `red-500` |
| **Body background** | Gris claro | `#F5F8FB` | `rgb(245, 248, 251)` | `slate-50` |
| **Card/White** | Blanco | `#FFFFFF` | `rgb(255, 255, 255)` | `white` |

### Tailwind CSS 4 — Custom Theme

```css
/* app/assets/stylesheets/application.css */
@import "tailwindcss";

@theme {
  /* Brand colors */
  --color-cec-navy: #262B40;
  --color-cec-navy-light: #363B54;
  --color-cec-navy-dark: #1A1E2E;
  --color-cec-gold: #F5B759;
  --color-cec-gold-light: #F8BD7A;
  --color-cec-gold-dark: #E5A040;

  /* Semantic colors */
  --color-cec-success: #05A677;
  --color-cec-danger: #FA5252;
  --color-cec-warning: #FCC419;
  --color-cec-info: #339AF0;
}
```

### Colores de Estado de Paquete

Estos son los colores usados en la leyenda del listado de paquetes:

| Estado | Color fondo | Color texto | Tailwind classes |
|--------|-------------|-------------|------------------|
| PRE-ALERTA | Amarillo claro | Texto oscuro | `bg-yellow-100 text-yellow-800` |
| FACTURADO | Verde claro | Texto oscuro | `bg-green-100 text-green-800` |
| ADUANA | Azul claro | Texto oscuro | `bg-blue-100 text-blue-800` |
| DISPONIBLE | Verde solido | Blanco | `bg-emerald-600 text-white` |
| ENTREGADO | Gris | Texto oscuro | `bg-gray-100 text-gray-600` |
| ANULADO | Rojo claro | Texto rojo | `bg-red-100 text-red-700` |
| EN MANIFIESTO | Indigo claro | Texto oscuro | `bg-indigo-100 text-indigo-800` |

### Flags Especiales (leyenda paquetes)

| Flag | Color | Significado |
|------|-------|-------------|
| P.A. | Badge azul | Pre-Alerta vinculada |
| P.F. | Badge verde | Pre-Factura generada |
| Amarillo | Fila amarilla | Solicito Cambio de Servicio |
| Azul | Fila azul | Retener en Miami |

---

## Tipografia

| Uso | Font | Tailwind |
|-----|------|----------|
| **UI general** | Inter | `font-sans` (configurar en Tailwind) |
| **Monospace** (trackings, codigos) | JetBrains Mono o system mono | `font-mono` |

```css
@theme {
  --font-sans: "Inter", ui-sans-serif, system-ui, sans-serif;
  --font-mono: "JetBrains Mono", ui-monospace, monospace;
}
```

---

## Iconos — Heroicons

**Libreria:** [Heroicons](https://heroicons.com/) v2 (outline 24px para navigation, solid 20px para inline)

Razones:
- Creados por el equipo de Tailwind CSS — integrados nativamente
- SVG inline — no dependencia externa, tree-shaking automatico
- Dos estilos: outline (sidebar nav) y solid (badges, botones)
- Gem disponible: `heroicon` para Rails helpers

### Instalacion

```ruby
# Gemfile
gem "heroicon"
```

### Mapeo de Iconos por Seccion

| Seccion | Icono | Heroicon name |
|---------|-------|---------------|
| Home | Casa | `home` |
| Estadisticas | Grafica | `chart-bar` |
| Mi Dia | Calendario | `calendar-days` |
| Etiquetar | Etiqueta | `tag` |
| Manifiestos | Caja/Envio | `cube` |
| Paquetes | Paquete | `archive-box` |
| Pre-Facturas | Documento | `document-text` |
| Pre-Alertas | Campana | `bell-alert` |
| Ventas | Moneda | `currency-dollar` |
| Recibos | Recibo | `receipt-percent` |
| Clientes | Personas | `users` |
| Entregas | Camion | `truck` |
| Marketing | Megafono | `megaphone` |
| Correos | Email | `envelope` |
| WhatsApp | Chat | `chat-bubble-left-right` |
| SMS | Telefono | `device-phone-mobile` |
| Configuraciones | Engranaje | `cog-6-tooth` |
| Reportes | Tabla | `table-cells` |
| Productos | Cubo | `cube-transparent` |
| Administracion | Escudo | `shield-check` |
| Buscar | Lupa | `magnifying-glass` |
| Filtros | Embudo | `funnel` |
| Agregar | Plus | `plus` |
| Eliminar | Basura | `trash` |
| Editar | Lapiz | `pencil-square` |
| Detalles | Ojo | `eye` |
| Cerrar sesion | Salir | `arrow-right-start-on-rectangle` |

### Uso en ERB

```erb
<%# Sidebar nav icon (outline, 24px) %>
<%= heroicon "home", variant: :outline, class: "w-5 h-5" %>

<%# Inline badge icon (solid, 20px) %>
<%= heroicon "bell-alert", variant: :solid, class: "w-4 h-4" %>
```

---

## ViewComponents

**Gem:** `view_component` (GitHub)

```ruby
# Gemfile
gem "view_component"
```

### Catalogo de Componentes

#### 1. Layout Components

| Componente | Proposito | Props |
|------------|-----------|-------|
| `Sidebar::LinkComponent` | Link individual del sidebar | `label:, path:, icon:, active:, badge_count:` |
| `Sidebar::SectionComponent` | Grupo colapsable del sidebar | `title:, icon:, expanded:` |
| `PageHeaderComponent` | Titulo + breadcrumb + botones accion | `title:, breadcrumbs:, actions:` |
| `EmptyStateComponent` | Mensaje cuando no hay datos | `title:, description:, icon:, action_path:` |

#### 2. Data Display Components

| Componente | Proposito | Props |
|------------|-----------|-------|
| `DataTableComponent` | Tabla con headers + sorting | `columns:, records:, sortable:` |
| `StatusBadgeComponent` | Badge de estado con color | `status:, size:` |
| `PackageFlagComponent` | Flag P.A./P.F./Amarillo/Azul | `flag_type:` |
| `CardComponent` | Card generico (mobile paquetes) | `title:, subtitle:, body:, footer:` |
| `StatCardComponent` | KPI card para dashboard | `label:, value:, icon:, trend:` |

#### 3. Form Components

| Componente | Proposito | Props |
|------------|-----------|-------|
| `FilterPanelComponent` | Panel de filtros colapsable | `filters:, collapsible:` |
| `SearchBarComponent` | Barra busqueda con placeholder | `placeholder:, url:, method:` |
| `DateRangeComponent` | Par fecha inicio/fin | `start_name:, end_name:` |
| `ClientAutocompleteComponent` | Autocomplete cliente por codigo | `name:, url:` |
| `ToggleFilterComponent` | Toggle switch para filtros | `label:, name:, checked:` |

#### 4. Action Components

| Componente | Proposito | Props |
|------------|-----------|-------|
| `ButtonComponent` | Boton reutilizable (primary/secondary/danger) | `label:, variant:, icon:, size:, href:, method:` |
| `ActionMenuComponent` | Menu acciones por fila de tabla | `actions:` |
| `ConfirmDialogComponent` | Modal de confirmacion | `title:, message:, confirm_text:, cancel_text:` |
| `FlashMessageComponent` | Notificacion flash | `type:, message:, dismissible:` |

#### 5. Domain-Specific Components

| Componente | Proposito | Props |
|------------|-----------|-------|
| `PackageCardComponent` | Card paquete (mobile view) | `package:` |
| `PreAlertaCardComponent` | Card pre-alerta (client grid) | `pre_alerta:` |
| `ManifiestoRowComponent` | Fila de tabla manifiesto | `manifiesto:` |
| `TrackingInputComponent` | Input tracking con validacion duplicado | `name:, client_code:` |
| `LeyendaComponent` | Leyenda de colores paquetes | — |

### Estructura de archivos

```
app/components/
  sidebar/
    link_component.rb
    link_component.html.erb
    section_component.rb
    section_component.html.erb
  page_header_component.rb
  page_header_component.html.erb
  status_badge_component.rb
  status_badge_component.html.erb
  button_component.rb
  button_component.html.erb
  data_table_component.rb
  data_table_component.html.erb
  filter_panel_component.rb
  filter_panel_component.html.erb
  ...
```

---

## Patrones UI Estandar

### Patron: Pagina Lista (Admin)

```
┌─────────────────────────────────────────────┐
│ PageHeaderComponent                          │
│  [Titulo]                    [+ Nuevo] [Btn] │
├─────────────────────────────────────────────┤
│ FilterPanelComponent (colapsable en mobile)  │
│  [Tipo Envio ▼] [Estado ▼] [Fecha ↔ Fecha]  │
│  [□ Mostrar facturados] [□ Incluir antiguos] │
├─────────────────────────────────────────────┤
│ SearchBarComponent                           │
│  [🔍 Buscar por tracking, cliente...]        │
├─────────────────────────────────────────────┤
│ DataTableComponent (desktop)                 │
│  Fecha | No. | Cliente | Estado | Monto | ⋮  │
│  ─────────────────────────────────────────── │
│  ...filas...                                 │
├─────────────────────────────────────────────┤
│ Paginacion: [< 1 2 3 >]  Mostrando 1-25/500 │
└─────────────────────────────────────────────┘
```

### Patron: Dashboard Home (secciones con botones)

```
┌─────────────────────────────────────────────┐
│ Miami                                        │
│ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│ │ Etiquetar│ │Manifiesto│ │ Clientes │ ...  │
│ └──────────┘ └──────────┘ └──────────┘      │
├─────────────────────────────────────────────┤
│ Caja                                         │
│ ┌───────────┐ ┌─────────────┐ ...           │
│ │Pre-Facturas│ │Todos Paquetes│              │
│ └───────────┘ └─────────────┘               │
└─────────────────────────────────────────────┘
```

---

## Dark Mode

El sistema actual tiene toggle "Oscuro" en el header. Implementar con Tailwind `dark:` variant.

```erb
<%# Toggle en header %>
<button data-action="click->dark-mode#toggle">
  <%= heroicon "moon", variant: :outline, class: "w-5 h-5 dark:hidden" %>
  <%= heroicon "sun", variant: :outline, class: "w-5 h-5 hidden dark:block" %>
</button>
```

```css
/* Colores dark mode */
/* body: bg-slate-50 → dark:bg-slate-900 */
/* sidebar: bg-cec-navy → dark:bg-slate-950 */
/* cards: bg-white → dark:bg-slate-800 */
/* text: text-gray-800 → dark:text-gray-100 */
```

---

## Resumen de Decisiones

| Decision | Eleccion | Razon |
|----------|----------|-------|
| CSS Framework | Tailwind CSS 4 | Ya definido en stack |
| Iconos | Heroicons v2 (gem `heroicon`) | Nativos de Tailwind, SVG inline |
| Componentes | ViewComponent (gem) | Estandar Rails, testeable, reutilizable |
| Tipografia | Inter (sans) + JetBrains Mono | Moderna, legible, buena en tablas |
| Paleta | Basada en sistema actual (#262B40 navy + #F5B759 gold) | Continuidad de marca |
| Dark mode | Tailwind `dark:` variant + Stimulus toggle | Ya existe en sistema actual |
| Responsive | Mobile-first (ya documentado en 04_diseno_responsive.md) | Clientes usan celular |
| Imagenes | Logo PNG existente + Heroicons SVG | Minimo peso, maximo rendimiento |
