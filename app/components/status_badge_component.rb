class StatusBadgeComponent < ViewComponent::Base
  COLORS = {
    "activo" => "bg-green-100 text-green-800",
    "inactivo" => "bg-gray-100 text-gray-800",
    "pendiente" => "bg-yellow-100 text-yellow-800",
    "en_proceso" => "bg-blue-100 text-blue-800",
    "en_miami" => "bg-indigo-100 text-indigo-800",
    "en_transito" => "bg-purple-100 text-purple-800",
    "en_aduana" => "bg-orange-100 text-orange-800",
    "en_bodega" => "bg-teal-100 text-teal-800",
    "listo_entrega" => "bg-emerald-100 text-emerald-800",
    "entregado" => "bg-green-100 text-green-800",
    "facturado" => "bg-cyan-100 text-cyan-800",
    "pagado" => "bg-green-100 text-green-700",
    "anulado" => "bg-red-100 text-red-800",
    "devuelto" => "bg-rose-100 text-rose-800",
    "retenido" => "bg-amber-100 text-amber-800",
    "extraviado" => "bg-red-100 text-red-700"
  }.freeze

  def initialize(status:, label: nil)
    @status = status.to_s
    @label = label || @status.humanize
  end

  def call
    content_tag :span, @label,
      class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{color_classes}"
  end

  private

  def color_classes
    COLORS[@status] || "bg-gray-100 text-gray-800"
  end
end
