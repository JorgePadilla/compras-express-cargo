# CEC — Design System

## Brand Identity (del sistema actual)

**Logo:** "Compras Express" con icono de persona corriendo en rojo.
- "Compras" en rojo/marron oscuro
- "Express" en azul cursiva
- Icono runner en rojo

**Archivo:** `app/assets/images/logo_compras_express.png` (extraer del sistema actual)

---

## Paleta de Colores — Navy · Gold · Teal (autoritativa, Abril 2026)

> La paleta vigente del Portal Rails (cliente y admin) es **Navy · Gold · Teal**
> más neutrales slate, rojo (errores) y amber (notas). Cualquier tono fuera de
> esta lista está prohibido en `app/views/` y `app/components/` — ver
> `test/lint/banned_colors_test.rb`.

### Tokens de marca

| Rol | Token Tailwind | Hex | Uso |
|---|---|---|---|
| **Primary chrome** | `cec-navy` / `cec-navy-dark` / `cec-navy-light` | `#1B2559` / `#111C44` / `#2D3A7B` | Sidebar, headers, texto primario, estados info |
| **Accent / CTA** | `cec-gold` / `cec-gold-dark` / `cec-gold-light` | `#FFB547` / `#E69E2E` / `#FFCA6E` | Botones submit, stepper activo, warnings, selecciones foco |
| **Secondary accent** | `cec-teal` / `cec-teal-dark` / `cec-teal-light` | `#00B4D8` / `#0096C7` / `#48CAE4` | Botones secundarios, estados éxito, stepper completado |
| **Neutral** | `slate-*` (Tailwind) | — | Bordes, fondos recessed, texto inactivo |
| **Danger** | `red-*` + `cec-danger` | `#EF4444` | Errores, acciones destructivas, límite CKA/CKM |
| **Warning / notes** | `amber-*` (Tailwind) | — | Tarjeta "Notas de tu cuenta" y paneles informativos discretos |

Los aliases semánticos `cec-success`, `cec-info`, `cec-warning` son atajos que
apuntan respectivamente a `cec-teal`, `cec-navy`, `cec-gold` (ver
`app/assets/tailwind/application.css`).

### Chips de estado — 5 familias semánticas

`StatusBadgeComponent` colapsa todos los estados logísticos a 5 cubetas. La
etiqueta (texto humanizado) distingue los sub-estados; el color comunica la
categoría.

| Familia | Clase | Estados |
|---|---|---|
| **Success** (teal) | `bg-cec-teal/10 text-cec-teal-dark ring-1 ring-cec-teal/30` | `activo`, `disponible`, `listo_entrega`, `entregado`, `pagado`, `facturado` |
| **Info** (navy) | `bg-cec-navy/5 text-cec-navy ring-1 ring-cec-navy/20` | `en_proceso`, `en_miami`, `en_transito`, `en_bodega`, `en_bodega_hn`, `recibido`, `etiquetado`, `en_manifiesto`, `enviado`, `pre_facturado`, `creado` |
| **Warning** (gold) | `bg-cec-gold/10 text-cec-gold-dark ring-1 ring-cec-gold/30` | `pendiente`, `pre_alerta`, `retenido`, `en_aduana` |
| **Danger** (red) | `bg-red-50 text-red-700 ring-1 ring-red-600/20` | `anulado`, `extraviado`, `devuelto` |
| **Neutral** (slate) | `bg-slate-100 text-slate-600 ring-1 ring-slate-500/20` | `inactivo` + fallback por defecto |

### Opciones de pre-alerta

| Opción | Clase | Razón |
|---|---|---|
| **Reempaque** | `bg-cec-teal/10 text-cec-teal-dark ring-1 ring-cec-teal/30` | Opción operativa → teal frío |
| **Consolidado** | `bg-cec-gold/10 text-cec-gold-dark ring-1 ring-cec-gold/30` | Opción premium → oro cálido |
| **Notificado / Vinculado** | `bg-cec-teal/10 text-cec-teal-dark ring-1 ring-cec-teal/30` | Confirmación de sistema → éxito teal |

### Tonos prohibidos

Las siguientes familias de Tailwind están **prohibidas** en `app/views/` y
`app/components/`:

```
emerald · green · lime · sky · cyan · indigo · violet ·
purple · fuchsia · pink · rose · orange · yellow
```

El test `test/lint/banned_colors_test.rb` falla si alguna de ellas reaparece.

### Gradientes permitidos

Sólo dos gradientes decorativos están autorizados a nivel global:

- `.sidebar-gradient` — `cec-navy → cec-navy-dark` (chrome del sidebar)
- `.btn-gold-gradient` — `cec-gold → cec-gold-dark` (tratamiento de CTA primario)

Gradientes ad-hoc como `from-emerald-*`, `from-gray-500 to-gray-600` o
`from-white to-gray-50` decorativos fueron removidos y no deben reintroducirse.

### Contraste — `cec-teal` rellena, `cec-teal-deep` entinta

WCAG AA pide **4.5:1** para texto y **3:1** para elementos de interfaz (bordes,
iconos, anillos de foco). Dos combinaciones de la paleta **no llegan**, y son
las que más se usaban:

| combinación | ratio | veredicto |
|---|---:|---|
| blanco sobre `cec-teal` `#00B4D8` | **2.46** | falla |
| `text-cec-teal` sobre blanco | **2.46** | falla |
| blanco sobre `cec-teal-dark` `#0096C7` | 3.39 | falla para texto |
| **`cec-navy-dark` sobre `cec-teal`** | **6.69** | ✅ así se usa |
| **`cec-teal-deep` `#007BA3` sobre blanco** | **4.81** | ✅ así se usa |

Por eso existe `--color-cec-teal-deep`. La regla, en una línea:

> **`cec-teal` es un fondo. `cec-teal-deep` es una tinta.**
>
> Si el teal va *detrás* de algo, es `cec-teal` y la letra encima va
> `cec-navy-dark`. Si el teal *es* lo que se lee —texto, borde, anillo de
> foco— es `cec-teal-deep`, y en modo oscuro `cec-teal-light` (7.58:1).

Otras que la auditoría de PR-BTN.1 encontró abajo del mínimo y ya no se usan
en botones: `cec-danger` `#EF4444` con blanco (3.76 → usar `red-600`, 4.83),
`amber-600` con blanco (3.19 → `amber-700`, 5.02), `text-gray-400` (2.54 →
`gray-500`, 4.83), `text-red-400` (2.77 → `red-500`, 3.76) y
`dark:text-cec-navy-light` sobre `gray-900` (**1.69** → `cec-gold`, 10.10).

---

## Botones — `ButtonComponent`

**Un botón nuevo se escribe con `ButtonComponent`, no a mano.** Los variants
llevan el ratio de contraste en el comentario del código; si alguno se toca,
el número se recalcula.

| variant | uso | ratio |
|---|---|---:|
| `primary` | la acción principal — navy **plano** | 14.43 |
| `secondary` | acción alterna sobre fondo claro | 7.56 |
| `ghost` | Cancelar / Volver / Limpiar | 7.56 |
| `gold` | CTA de cierre (Guardar, Facturar) | 9.39 |
| `teal` | acción afirmativa; letra `cec-navy-dark`, no blanca | 6.69 |
| `outline_navy` | secundaria con borde; en oscuro va a **gold** | 10.31 |
| `outline_teal` | secundaria con borde teal (`-deep`) | 4.81 |
| `danger` | destructiva — `red-600` | 4.83 |
| `soft_danger` | destructiva "suave" (Anular) | 5.91 |
| `warning` | aviso — `amber-700` | 5.02 |

Tamaños: `:xs` `:sm` `:md` (default) `:lg`. El icono sigue al botón (16 / 16 /
20 / 20 px).

**Lo que el componente garantiza y no hay que volver a escribir:**

- **Anillo de foco visible** en los diez variants. Un variant nuevo sin anillo
  rompe la suite (`button_component_test.rb`).
- **`type="button"` por defecto.** Un `<button>` sin type dentro de un `<form>`
  es `submit` — así, "Limpiar" en `/entrega_personal` reseteaba el formulario
  **y lo enviaba**.
- **Nombre accesible obligatorio**: un botón de solo icono sin `label:` levanta
  `ArgumentError` en vez de quedar mudo para un lector de pantalla.
- **`disabled:`** con un solo tratamiento (`opacity-50` + `cursor-not-allowed`),
  y un `<span role="button" aria-disabled>` cuando hay `href` — un `<a>`
  deshabilitado no existe en HTML.
- **`method:`** distinto de `:get` sale como `button_to`, no como un `<a>` que
  depende de Turbo.

**Qué se queda crudo, a propósito:** las tarjetas-botón de tipo de envío en
`/etiquetar`, los CTA de las pantallas de sesión, los adornos absolutos dentro
de un input (ojo de contraseña, limpiar fecha) y las pills de filtro con clases
interpoladas. Su forma es incompatible con `inline-flex items-center` — pero
igual llevan anillo de foco y nombre accesible.

### El trinquete — `test/lint/botones_test.rb`

El componente existía desde antes de `PR-BTN.1` y aun así **el 82% de los
botones se seguía escribiendo a mano**. Por eso hay un lint.

Lleva un **presupuesto por archivo** que falla en las **dos** direcciones:

- **sube** → entró un botón crudo nuevo. Usá `ButtonComponent`.
- **baja** → migraste y no actualizaste el número. Dejarlo inflado le abre
  lugar a botones crudos nuevos que el lint no vería entrar.

```
bin/rails botones:presupuesto     # imprime los hashes listos para pegar
```

Un segundo presupuesto, `BLANCO_SOBRE_TEAL`, cuenta los `bg-cec-teal` con
`text-white` en el mismo elemento. Tiene que llegar a `{}` cuando termine la
migración.

**Si de verdad tiene que ser un botón crudo** —una tarjeta, un CTA de sesión,
un adorno dentro de un input— corré la tarea, pegá el hash y dejá un comentario
diciendo por qué. Crudo a propósito sigue contando: su número tampoco puede
subir solo.

### Accesibilidad — `test/lint/botones_accesibles_test.rb`

Crudo a propósito **no** es exento. Un segundo lint, sin lista de excepciones,
exige de **todos** los `<button>` de la app:

- **Nombre accesible.** Un botón de solo icono necesita `aria-label`. `title`
  **no alcanza**: es el tooltip del mouse, no aparece con teclado y los
  lectores de pantalla no lo usan como nombre. Cuando hay texto visible no hace
  falta — el nombre sale del contenido.
- **No apagar el foco sin reemplazarlo.** `focus:outline-none` suelto le saca
  al navegador el único indicador que trae de fábrica. Si hay que cambiarlo, va
  `foco-cec`.

`ButtonComponent` ya cumple las dos por construcción: `label:` es obligatorio
cuando no hay contenido, y el anillo viene en la base.

---

## Paleta de Colores — Referencia histórica (sistema legacy)

> La siguiente tabla documenta la paleta observada en el sistema ASP.NET
> previo y sólo se mantiene como referencia histórica. **No usar estos tokens
> en código nuevo** — usar la paleta Navy · Gold · Teal de la sección anterior.

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

Los estados **no tienen color propio**: pasan por `StatusBadgeComponent`, que
los mapea a las cinco familias de arriba (`COLORS` en
`app/components/status_badge_component.rb`). En los listados de operación el
rótulo va corto (`EstadoPaqueteHelper::CORTAS`, `PR-C7.25`) y el largo queda en
el `title`; el cliente sigue viendo el largo.

> La tabla que vivía acá (`bg-yellow-100`, `bg-emerald-600`, `bg-indigo-100`…)
> era del sistema viejo y usaba tonos que `test/lint/banned_colors_test.rb`
> prohíbe. Se quitó el 2026-08-25 (`C16-07`).

### Flags de la fila (leyenda de `/paquetes`)

Lo que dice `app/views/paquetes/index.html.erb` hoy, en el orden en que gana
(es un `elsif`: una fila lleva un solo fondo):

| Flag | Fila | Significado |
|------|------|-------------|
| Retener en Miami | ámbar claro `bg-amber-50` | la bandera `retener_miami` (no el estado `retenido`, que es de Honduras) |
| Cambio de servicio | ámbar `bg-amber-100/60` | `solicito_cambio_servicio` |
| Pre-Factura | azul claro `bg-blue-50` | ya entró a una pre-factura |
| Pre-Alerta | teal `bg-cec-teal/5` | vino anunciado |

Y en la **etiqueta impresa**, el retenido en Miami dice **`RET`** donde va el
servicio (`etiqueta_tipo_envio`, `C16-07`): es el texto más grande de la
etiqueta porque es con lo que separan la carga antes de empacar, y una caja
retenida no se empaca.

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
| Responsive | Mobile-first (el planteo original está en `historico/04_diseno_responsive.md`) | Clientes usan celular |
| Imagenes | Logo PNG existente + Heroicons SVG | Minimo peso, maximo rendimiento |
