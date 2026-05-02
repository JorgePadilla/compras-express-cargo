# Iconos compactos de acción para celdas de tabla. Reemplaza los
# link_to "Editar" / "Ver" / "Borrar" inline con iconos consistentes.
#
# Yusef 2026-05-02: pidió aplicar el patrón de /paquetes (iconos
# pencil-square + trash) al resto del proyecto.
#
# Uso:
#   <%= render RowActionComponent.new(action: :edit, href: edit_cliente_path(c), label: "Editar cliente") %>
#   <%= render RowActionComponent.new(action: :delete, href: cliente_path(c),
#                                      confirm: "¿Eliminar?", label: "Borrar cliente") %>
#   <%= render RowActionComponent.new(action: :view, href: cliente, label: "Ver cliente") %>
#
# Conjuntos típicos por dominio:
#   - Edit-only catálogos: [:edit]
#   - Operacionales: [:view, :edit, :annul]
#   - Documentos comerciales: [:view, :pdf, :email, :annul]
class RowActionComponent < ViewComponent::Base
  # Mapping action → { icon, color_classes, default_method }
  ACTIONS = {
    edit: {
      icon: "pencil-square",
      color: "text-gray-400 hover:text-cec-navy dark:hover:text-cec-gold",
      method: :get,
      destructive: false
    },
    delete: {
      icon: "trash",
      color: "text-red-400 hover:text-red-600",
      method: :delete,
      destructive: true,
      default_confirm: "¿Eliminar este registro? Esta acción no se puede deshacer."
    },
    view: {
      icon: "eye",
      color: "text-gray-400 hover:text-cec-teal dark:hover:text-cec-teal-light",
      method: :get,
      destructive: false
    },
    pdf: {
      icon: "document-arrow-down",
      color: "text-gray-400 hover:text-cec-gold-dark dark:hover:text-cec-gold",
      method: :get,
      destructive: false
    },
    print: {
      icon: "printer",
      color: "text-gray-400 hover:text-cec-navy dark:hover:text-cec-gold",
      method: :get,
      destructive: false,
      target: "_blank"
    },
    duplicate: {
      icon: "document-duplicate",
      color: "text-gray-400 hover:text-cec-teal dark:hover:text-cec-teal-light",
      method: :get,
      destructive: false
    },
    annul: {
      icon: "x-circle",
      color: "text-red-400 hover:text-red-600",
      method: :delete,
      destructive: true,
      default_confirm: "¿Anular este registro? Esta acción no se puede deshacer."
    },
    approve: {
      icon: "check-circle",
      color: "text-gray-400 hover:text-cec-teal dark:hover:text-cec-teal-light",
      method: :post,
      destructive: false
    },
    email: {
      icon: "envelope",
      color: "text-gray-400 hover:text-cec-navy dark:hover:text-cec-gold",
      method: :post,
      destructive: false,
      default_confirm: "¿Reenviar email al cliente?"
    }
  }.freeze

  def initialize(action:, href:, label: nil, disabled: false, confirm: nil, method: nil, target: nil)
    @action_key = action.to_sym
    @config = ACTIONS.fetch(@action_key)
    @href = href
    @label = label.presence || @action_key.to_s.humanize
    @disabled = disabled
    @confirm = confirm || (@config[:destructive] ? @config[:default_confirm] : nil)
    @method = method || @config[:method]
    @target = target || @config[:target]
  end

  def base_classes
    "inline-flex items-center justify-center w-7 h-7 rounded focus-visible:outline-2 focus-visible:outline-offset-2 transition-colors"
  end

  def disabled_classes
    "#{base_classes} text-gray-300 dark:text-gray-600 cursor-not-allowed"
  end

  def active_classes
    focus = @config[:destructive] ? "focus-visible:outline-red-500" : "focus-visible:outline-cec-teal"
    "#{base_classes} #{@config[:color]} #{focus}"
  end

  def icon_name
    @config[:icon]
  end

  def needs_button?
    @method != :get
  end
end
