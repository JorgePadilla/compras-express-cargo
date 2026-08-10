# El botón del sistema. Un solo lugar donde se decide cómo se ve y cómo se
# comporta un botón en toda la app.
#
# ── PR-BTN.1: qué cambió y por qué ────────────────────────────────────────
#
# La auditoría encontró 334 elementos con forma de botón y **67 strings de
# clases distintos** para hacer lo mismo. Pero el problema de fondo no era la
# variedad, era que varias de esas combinaciones **no se leen**:
#
#   · blanco sobre `cec-teal`      2.46:1  (WCAG AA pide 4.5:1 para texto)
#   · blanco sobre `cec-danger`    3.76:1
#   · `dark:text-cec-navy-light`   1.69:1  ← el "Limpiar (F2)" de /etiquetar
#                                            era ilegible en modo oscuro
#
# Y **1 de 131 botones tenía estilo de foco**. Este componente tampoco emitía
# ninguno, así que quien navega con teclado no veía dónde estaba parado.
#
# Las decisiones de Jorge (2026-08-10):
#
#   1. El teal de marca NO se toca. `#00B4D8` sigue siendo el fondo; lo que
#      cambia es la letra: blanco → `cec-navy-dark`. 2.46 → 6.69:1.
#   2. `primary` pasa a navy PLANO. El gradiente solo lo tenían los 59 botones
#      ya migrados; los 46 crudos de la app siempre fueron planos.
class ButtonComponent < ViewComponent::Base
  # Cada variant lleva su ratio de contraste en el comentario. Si alguno se
  # toca, el número tiene que recalcularse — es lo único que distingue una
  # decisión de diseño de una corazonada.
  VARIANTS = {
    # Navy sólido, no gradiente. Blanco sobre #1B2559 = 14.43:1.
    primary: "bg-cec-navy text-white hover:bg-cec-navy-light shadow-sm",

    # 7.56:1 en claro, 13.34:1 en oscuro.
    #
    # El borde `gray-300` da 1.47:1 contra blanco y no llega al 3:1 de 1.4.11.
    # Se acepta a propósito: el botón lleva texto legible, así que
    # identificarlo no depende del borde. Subirlo a `gray-500` (3.03:1) lo
    # haría parecer un input deshabilitado.
    secondary: "bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-100 " \
               "border border-gray-300 dark:border-gray-600 " \
               "hover:bg-gray-50 dark:hover:bg-gray-700 shadow-sm",

    # El "Limpiar (F2)" de /etiquetar. 10.31:1 en claro.
    #
    # En oscuro va a **gold**, no a `cec-navy-light`: #2D3A7B sobre gray-900 da
    # 1.69:1 — es el defecto peor de toda la auditoría, y estaba en la pantalla
    # que más se usa. `cec-gold` sobre gray-900 da 10.10:1.
    outline_navy: "border border-cec-navy text-cec-navy hover:bg-cec-navy/5 " \
                  "dark:border-cec-gold/60 dark:text-cec-gold dark:hover:bg-cec-gold/10",

    # `red-600`, no `cec-danger`: blanco sobre #EF4444 da 3.76:1 y sobre
    # #DC2626 da 4.83:1. Los botones crudos de la app ya usaban red-600 — el
    # componente era el que estaba mal.
    danger: "bg-red-600 text-white hover:bg-red-700 shadow-sm",

    # El destructivo "suave" de los 7 `button_to` de anular. 5.91:1.
    soft_danger: "bg-red-50 text-red-700 border border-red-200 hover:bg-red-100 " \
                 "dark:bg-red-900/30 dark:text-red-300 dark:border-red-800 " \
                 "dark:hover:bg-red-900/50",

    # `amber-700`, no `amber-600`: blanco sobre #D97706 da 3.19:1; sobre
    # #B45309 da 5.02:1. Amber está autorizado (no está en la lista prohibida
    # de `banned_colors_test`, que sí veta orange y yellow).
    warning: "bg-amber-700 text-white hover:bg-amber-800 shadow-sm",

    # Uno de los dos gradientes autorizados del design system. Absorbe los 4
    # `bg-cec-gold` planos de la app: dos oros que nadie sabe nombrar no son
    # dos variantes. `cec-navy-dark` sobre gold = 9.39:1.
    gold: "btn-gold-gradient text-cec-navy-dark font-semibold shadow-sm shadow-cec-gold/25",

    # El fondo de marca queda igual. Cambia la tinta: 2.46 → 6.69:1, y sobre
    # el hover (`cec-teal-dark`) 4.86:1.
    teal: "bg-cec-teal text-cec-navy-dark hover:bg-cec-teal-dark shadow-sm",

    # Borde y texto en `cec-teal-deep`: `border-cec-teal` da 2.46:1 y no llega
    # al 3:1 de 1.4.11 para un borde. 4.81:1 en claro, 7.58:1 en oscuro.
    outline_teal: "border border-cec-teal-deep text-cec-teal-deep hover:bg-cec-teal/10 " \
                  "dark:border-cec-teal-light dark:text-cec-teal-light " \
                  "dark:hover:bg-cec-teal-light/10",

    ghost: "text-gray-600 dark:text-gray-300 hover:text-gray-900 dark:hover:text-gray-100 " \
           "hover:bg-gray-100 dark:hover:bg-gray-800"
  }.freeze

  # `:sm` y `:xs` están invertidos respecto de antes, a propósito. El `:sm`
  # viejo era `text-xs`, pero el chico dominante en la app es `text-sm` (23
  # usos contra 5). El componente se alinea con lo que la app ya muestra.
  SIZES = {
    xs: "px-3 py-1.5 text-xs",
    sm: "px-3 py-1.5 text-sm",
    md: "px-4 py-2 text-sm",
    lg: "px-6 py-3 text-base"
  }.freeze

  # Lo que aplica a TODOS los variants.
  #
  # El anillo de foco es un solo par de colores para los diez variants, y eso
  # funciona por el `outline-offset-2`: el anillo cae sobre el **fondo de la
  # página**, no sobre el botón, así que su contraste depende de la superficie
  # (blanco/gray-50 en claro, gray-900/gray-800 en oscuro) y nunca del variant.
  # 4.81:1 en claro, 3.68:1 en oscuro.
  #
  # `transition-colors` y no `transition-all`: `transition-all` anima también
  # el ancho del `outline`, y el anillo se ve borroneado al tabular.
  BASE = <<~CSS.squish
    inline-flex items-center justify-center gap-2 rounded-lg font-medium
    transition-colors duration-200
    focus-visible:outline-2 focus-visible:outline-offset-2
    focus-visible:outline-cec-teal-deep dark:focus-visible:outline-cec-teal-light
    disabled:opacity-50 disabled:cursor-not-allowed
    aria-disabled:opacity-50 aria-disabled:cursor-not-allowed
  CSS

  # `shortcut_label_only`: muestra "(F2)" pero NO registra `data-shortcut`.
  #
  # PR-10.c: hace falta cuando la pantalla ya escucha esa tecla por su cuenta.
  # `keyboard_shortcuts_controller` (montado en <body>) le hace click a
  # cualquier elemento con `data-shortcut`, así que si el Stimulus de la
  # pantalla también la escucha, la acción corre DOS veces — en
  # /entrega_personal el segundo `showModal()` sobre un <dialog> ya abierto
  # tiraba `InvalidStateError`.
  def initialize(variant: :primary, size: :md, href: nil, icon: nil,
                 type: nil, disabled: false, method: nil, label: nil,
                 confirm: nil, form: nil, form_class: nil, params: nil,
                 shortcut: nil, shortcut_label_only: false, **attrs)
    @variant = variant.to_sym
    @size = size.to_sym
    @href = href
    @icon = icon
    @type = type
    @disabled = disabled
    @method = method
    @label = label
    @confirm = confirm
    @form = form
    @form_class = form_class
    @params = params
    @shortcut = shortcut # ej. "F10" — label visual "(F10)"
    @shortcut_label_only = shortcut_label_only
    @attrs = attrs
  end

  def call
    verificar_nombre_accesible!

    return deshabilitado if @disabled
    return como_form     if @href && @method && @method.to_sym != :get
    return como_link     if @href

    como_boton
  end

  private

  # Un botón de solo icono sin nombre no lo puede usar quien navega con lector
  # de pantalla: se anuncia "botón" y nada más. La auditoría encontró 11 así.
  #
  # Falla al renderizar en vez de dejarlo pasar: un error en desarrollo es
  # barato, un botón mudo en producción no se descubre nunca.
  def verificar_nombre_accesible!
    return if content.present? || @label.present?

    raise ArgumentError,
          "ButtonComponent sin texto necesita `label:` — sin eso el botón " \
          "no tiene nombre accesible."
  end

  def clases
    @clases ||= [
      BASE,
      VARIANTS.fetch(@variant),
      SIZES.fetch(@size),
      @attrs[:class]
    ].compact_blank.join(" ")
  end

  # Los atributos que van al tag, SIN mutar `@attrs`.
  #
  # Antes esto hacía `@attrs.delete(:class)` y `@attrs.delete(:data)`: renderizar
  # dos veces la misma instancia perdía la clase y los data del caller en la
  # segunda pasada.
  def atributos
    @atributos ||= begin
      attrs = @attrs.except(:class, :data)
      attrs[:class] = clases

      data = (@attrs[:data] || {}).dup
      # Se mergea sin pisar los `data-*` del caller: muchos botones llevan
      # targets de Stimulus (`data-etiquetar-target="submitBtn"`) que tienen
      # que sobrevivir.
      data[:shortcut] = @shortcut if @shortcut.present? && !@shortcut_label_only
      data[:turbo_confirm] = @confirm if @confirm.present?
      attrs[:data] = data if data.any?

      attrs["aria-label"] = @label if @label.present?
      attrs
    end
  end

  def como_boton
    content_tag :button, type: @type || "button", **atributos do
      contenido
    end
  end

  def como_link
    link_to @href, **atributos do
      contenido
    end
  end

  # `button_to` para todo lo que no sea GET: un `<a>` con `method:` depende de
  # Turbo y no funciona sin JS.
  def como_form
    opciones = atributos.merge(method: @method)
    opciones[:form] = @form if @form
    opciones[:form_class] = @form_class if @form_class
    opciones[:params] = @params if @params

    button_to @href, **opciones do
      contenido
    end
  end

  # Un `<a>` deshabilitado no existe en HTML: se le saca el href y se marca con
  # `aria-disabled`. Mismo patrón que `RowActionComponent`, que ya lo resolvió.
  #
  # Nunca emite `data-shortcut`: un botón apagado no debería responder a F10.
  def deshabilitado
    if @href
      content_tag :span, role: "button", "aria-disabled": "true",
                         class: clases, "aria-label": @label do
        safe_join([ contenido, content_tag(:span, "(deshabilitado)", class: "sr-only") ])
      end
    else
      content_tag :button, **atributos.merge(type: @type || "button", disabled: true) do
        contenido
      end
    end
  end

  def contenido
    safe_join([ icono, content, shortcut_label ].compact)
  end

  # `disable_default_class` porque si no **`icon_size` no hace nada**.
  #
  # El gem antepone su clase por defecto (`h-6 w-6` para outline, ver
  # `config/initializers/heroicon.rb`), y el orden dentro del atributo `class`
  # no decide nada: decide el orden en el CSS. `.w-6` está DESPUÉS de `.w-4`
  # en el bundle de Tailwind, así que gana siempre. Resultado: todos los
  # iconos salían a 24px, incluso en un botón `text-xs`.
  #
  # El icono es decorativo —el nombre del botón sale del texto o del `label:`—
  # y el gem ya emite `aria-hidden="true"` por su cuenta. Hay un test que lo
  # fija, para que una actualización del gem no se lo lleve en silencio.
  def icono
    return nil if @icon.blank?

    helpers.heroicon(@icon, variant: :outline,
                            options: { class: icon_size, disable_default_class: true })
  end

  # "(F10)" pequeño y semitransparente al final del label cuando hay shortcut.
  def shortcut_label
    return nil if @shortcut.blank?

    content_tag :span, "(#{@shortcut})",
                class: "ml-1 text-[10px] opacity-70 font-normal"
  end

  def icon_size
    @size.in?(%i[xs sm]) ? "w-4 h-4" : "w-5 h-5"
  end
end
