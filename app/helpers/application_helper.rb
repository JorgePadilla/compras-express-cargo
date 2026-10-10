module ApplicationHelper
  # PR-D4.c — Renderiza un valor con un mini-botón de "copiar al
  # portapapeles" al lado. Usa Stimulus clipboard_controller.
  #
  # Uso:
  #   <%= copyable(@paquete.tracking, font_mono: true) %>
  #   <%= copyable(@paquete.numero_recepcion) %>
  #
  # Si `value` es blank devuelve "—" sin botón.
  def copyable(value, font_mono: false, css_class: "")
    return content_tag(:span, "—", class: "text-gray-400") if value.blank?

    text_class = "#{font_mono ? 'font-mono' : ''} text-gray-900 dark:text-gray-100 #{css_class}".strip

    content_tag :span,
                class: "inline-flex items-center gap-2 max-w-full align-middle",
                data: { controller: "clipboard", "clipboard-text-value": value.to_s } do
      safe_join([
        content_tag(:span, value, class: text_class),
        copy_button(label: "Copiar valor")
      ])
    end
  end

  # Renderiza solo el botón (sin valor) — útil para casos donde el
  # clipboard wrapper se arma a mano (ej. cliente con link_to + nombre).
  # Debe estar dentro de un wrapper con `data-controller="clipboard"` y
  # `data-clipboard-text-value="..."`.
  #
  # Los 3 SVGs (idle/ok/err) viven SIEMPRE en el DOM; el controller solo
  # toggle-ea visibility con CSS → cero reflow al cambiar feedback.
  # `tamano: :fila` lo deja del tamaño y el color de los íconos de una columna
  # «Acciones» (`RowActionComponent`: 28 px, `gray-500`), para que vaya al lado
  # de ellos sin verse de otra familia. El de siempre es el chico, pegado a un
  # dato.
  COPY_BUTTON_CLASES = {
    dato: "relative shrink-0 inline-flex items-center justify-center w-5 h-5 rounded text-gray-300 dark:text-gray-600 hover:text-cec-teal hover:bg-gray-100 dark:hover:text-cec-teal-light dark:hover:bg-gray-700 transition-colors align-middle",
    fila: "relative shrink-0 inline-flex items-center justify-center w-7 h-7 rounded foco-cec text-gray-500 dark:text-gray-400 hover:text-cec-teal dark:hover:text-cec-teal-light transition-colors"
  }.freeze

  def copy_button(label: "Copiar", tamano: :dato)
    icono = tamano == :fila ? "w-4 h-4" : "w-3.5 h-3.5"
    button_tag(type: "button",
               class: COPY_BUTTON_CLASES.fetch(tamano),
               title: label,
               "aria-label": label,
               data: { action: "clipboard#copy", "clipboard-target": "button" }) do
      safe_join([
        content_tag(:span, data: { "clipboard-target": "iconIdle" }) do
          heroicon("clipboard-document", variant: :outline, options: { class: icono })
        end,
        content_tag(:span, class: "hidden text-cec-teal dark:text-cec-teal-light", data: { "clipboard-target": "iconOk" }) do
          heroicon("check", variant: :solid, options: { class: icono })
        end,
        content_tag(:span, class: "hidden text-red-600 dark:text-red-400", data: { "clipboard-target": "iconErr" }) do
          heroicon("x-mark", variant: :solid, options: { class: icono })
        end
      ])
    end
  end
end
