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
                class: "inline-flex items-center gap-1.5 group",
                data: { controller: "clipboard", "clipboard-text-value": value.to_s } do
      safe_join([
        content_tag(:span, value, class: text_class),
        button_tag(type: "button",
                   class: "shrink-0 inline-flex items-center justify-center w-5 h-5 rounded text-gray-400 hover:text-cec-teal hover:bg-gray-100 dark:hover:text-cec-teal-light dark:hover:bg-gray-700 opacity-0 group-hover:opacity-100 focus:opacity-100 transition-opacity",
                   title: "Copiar",
                   "aria-label": "Copiar valor",
                   data: { action: "clipboard#copy", "clipboard-target": "button" }) do
          heroicon("clipboard-document", variant: :outline, options: { class: "w-3.5 h-3.5" })
        end
      ])
    end
  end
end
