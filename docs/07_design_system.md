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
| Enviado según política | navy `bg-cec-navy/5` | `enviado_por_politica` (`C18-06`): llegó sin identificación y se mandó por la política por defecto; la explicación le llega al cliente |
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

### Catálogo de componentes

Son los que existen en `app/components/` (**20**, 2026-08-26). El
catálogo anterior era el del diseño original y listaba componentes que nunca
se construyeron (`DataTableComponent`, `Sidebar::LinkComponent`,
`ConfirmDialogComponent`…): lo que hace falta se construye cuando hace falta,
y **se agrega acá** cuando nace. Los props son la firma real de `initialize`.

| Componente | Para qué | Props |
|---|---|---|
| `BitacoraComponent` | Bitácora (paper_trail) de un registro, en su ficha | `record:, label: nil, limit: 50` |
| `ButtonComponent` | **El** botón (ver «Botones»); el lint `botones_test` lo hace cumplir | `variant: :primary, size: :md, href: nil, icon: nil, type: nil, disabled: false, method: nil, label: nil, confirm: nil, form: nil, form_class: nil, params: nil, shortcut: nil, shortcut_label_only: false, **attrs` |
| `CajasPesoMedidasComponent` | Peso y medidas por caja con el repetidor; lo comparten `/etiquetar` y `/entrega_personal` | `f:, tipo_envio_id: nil, wrapper_class: "", valor_a_pagar: false, cotizador_url: nil, cajas_cargadas: {}` |
| `DashboardActivityItemComponent` | Renglón de la actividad reciente del dashboard | `href:, avatar_name:, eyebrow:, title:, time: nil` |
| `DashboardChartComponent` | Gráfica del dashboard | `series:` |
| `DashboardHeroComponent` | Encabezado con los números grandes del dashboard | `user:, health_status:, time: Time.zone.now` |
| `DashboardKpiCardComponent` | KPI card del dashboard | `title:, value:, icon:, accent:, delta:, series: [], decimals: 0, prefix: "", suffix: "", caption: nil, inverse_delta: false` |
| `DashboardPipelineComponent` | Embudo de estados del dashboard | `en_bodega:, en_transito:, disponibles:, pendientes:` |
| `EmptyStateComponent` | Mensaje cuando no hay datos | `title:, description: nil, icon: "inbox"` |
| `EnviadoPorPoliticaComponent` | «Enviado según política» (`C18-06`): casilla + listita de motivos + detalle, compuesto en `notas_al_cliente`; gemelo de retener, lint `enviado_por_politica_compartido_test` | `f:, motivos:` |
| `FormSectionComponent` | Sección de formulario con título y descripción | `title: nil, subtitle: nil, densidad: :comoda, alineacion_del_pie: "sm:justify-between", **attrs` |
| `PageHeaderComponent` | Título + breadcrumb + acciones | `title:, subtitle: nil` |
| `PaginationComponent` | Paginación (Pagy) | `collection:, label: "registros", per_page_options: DEFAULT_PER_PAGE_OPTIONS` |
| `PreAlertaCardComponent` | Card de pre-alerta en el portal | `pre_alerta:` |
| `QuickActionCardComponent` | Card de acceso rápido del dashboard | `title:, href:, icon:, subtitle: nil, accent: :teal` |
| `RetenerMiamiComponent` | «Retener en Miami» (`C11`): casilla + motivos del catálogo + nota; lint `retener_compartido_test` | `f:, motivos:` |
| `RowActionComponent` | Acción por fila de tabla | `action:, href:, label: nil, disabled: false, confirm: nil, method: nil, target: nil` |
| `SearchBarComponent` | Barra de búsqueda | `url:, placeholder: "Buscar...", value: nil, param: :q` |
| `StatusBadgeComponent` | Badge de estado; colapsa los estados a 5 cubetas (ver arriba) | `status:, label: nil, title: nil` |
| `StepperComponent` | Pasos de un flujo (wizard) | `steps:` |

Los dos de «marcar el paquete con una explicación» —retener y enviado según
política— son copias deliberadas uno del otro: misma casilla que despliega,
mismo catálogo administrable por un admin, mismo lint que exige que las tres
pantallas (`/etiquetar`, `/entrega_personal`, `paquetes/_form`) rendericen el
componente y ninguna escriba los motivos a mano.

### Estructura de archivos

```
app/components/
  bitacora_component.html.erb
  bitacora_component.rb
  button_component.rb
  cajas_peso_medidas_component.html.erb
  cajas_peso_medidas_component.rb
  dashboard_activity_item_component.html.erb
  dashboard_activity_item_component.rb
  dashboard_chart_component.html.erb
  dashboard_chart_component.rb
  dashboard_hero_component.html.erb
  dashboard_hero_component.rb
  dashboard_kpi_card_component.html.erb
  dashboard_kpi_card_component.rb
  dashboard_pipeline_component.html.erb
  dashboard_pipeline_component.rb
  empty_state_component.html.erb
  empty_state_component.rb
  enviado_por_politica_component.html.erb
  enviado_por_politica_component.rb
  form_section_component.html.erb
  form_section_component.rb
  page_header_component.html.erb
  page_header_component.rb
  pagination_component.html.erb
  pagination_component.rb
  pre_alerta_card_component.html.erb
  pre_alerta_card_component.rb
  quick_action_card_component.html.erb
  quick_action_card_component.rb
  retener_miami_component.html.erb
  retener_miami_component.rb
  row_action_component.html.erb
  row_action_component.rb
  search_bar_component.html.erb
  search_bar_component.rb
  status_badge_component.rb
  stepper_component.html.erb
  stepper_component.rb
```

---

## Fechas — siempre `flatpickr`, nunca el picker del navegador

**Regla:** ningún `date_field` / `date_field_tag` sin
`data: { controller: "flatpickr" }`. Lo hace cumplir
`test/lint/fechas_flatpickr_test.rb`.

Jorge, 2026-08-30, mirando el manifiesto: *"el date picker no es el que estamos
usando en el proyecto"*. Eran nueve campos y **ocho estaban con el nativo**: se
fueron quedando así, nadie decidió que fueran distintos.

No es solo estética. `app/javascript/controllers/flatpickr_controller.js` va con:

- **`disableMobile: true`** — fuerza su propio calendario en vez del nativo. En
  una tablet, el picker de Chrome en Android es la ruleta chiquita del sistema, y
  estas pantallas se usan con el dedo.
- **`locale: Spanish`** y `altFormat: d/m/Y` — se ve `30/08/2026` y se manda
  `2026-08-30`. El nativo muestra `yyyy-mm-dd` y cada navegador lo dibuja distinto.
- Un parche anti-autofill: el input visible que crea `altInput` no tiene `name`,
  y Chrome lo clasificaba como fecha de vencimiento de tarjeta.

**Las dos formas de montarlo:**

| | Cuándo | Ejemplo |
|---|---|---|
| Directo sobre el input | Filtros y campos simples | `app/views/paquetes/index.html.erb` |
| Wrapper + `flatpickr_target` + botón de limpiar | Cuando hace falta una × para vaciar | `app/views/paquetes/_form.html.erb` |

**Ojo con F2.** `f2-clear` hace `form.reset()`, que devuelve el input real a su
valor por defecto — pero flatpickr no se entera y el visible queda con lo de
antes. Hoy no se ve, porque los nueve formularios que usan ese controller
recargan la página al limpiar; `f2_clear_controller` igual avisa a las
instancias (`input._flatpickr?.clear()`) para el primero que use el modo sin
submit. Si aparece otro controller que limpie un formulario, tiene que hacer lo
mismo.

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
