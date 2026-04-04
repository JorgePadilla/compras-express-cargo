class StatusBadgeComponent < ViewComponent::Base
  COLORS = {
    "activo" => "bg-emerald-50 text-emerald-700 ring-1 ring-emerald-600/20",
    "inactivo" => "bg-gray-50 text-gray-600 ring-1 ring-gray-500/20",
    "pendiente" => "bg-yellow-50 text-yellow-700 ring-1 ring-yellow-600/20",
    "en_proceso" => "bg-blue-50 text-blue-700 ring-1 ring-blue-600/20",
    "en_miami" => "bg-indigo-50 text-indigo-700 ring-1 ring-indigo-600/20",
    "en_transito" => "bg-purple-50 text-purple-700 ring-1 ring-purple-600/20",
    "en_aduana" => "bg-orange-50 text-orange-700 ring-1 ring-orange-600/20",
    "en_bodega" => "bg-teal-50 text-teal-700 ring-1 ring-teal-600/20",
    "listo_entrega" => "bg-emerald-50 text-emerald-700 ring-1 ring-emerald-600/20",
    "entregado" => "bg-green-50 text-green-700 ring-1 ring-green-600/20",
    "facturado" => "bg-lime-50 text-lime-700 ring-1 ring-lime-600/20",
    "pagado" => "bg-green-50 text-green-700 ring-1 ring-green-600/20",
    "anulado" => "bg-red-50 text-red-700 ring-1 ring-red-600/20",
    "devuelto" => "bg-rose-50 text-rose-700 ring-1 ring-rose-600/20",
    "retenido" => "bg-amber-50 text-amber-700 ring-1 ring-amber-600/20",
    "extraviado" => "bg-red-50 text-red-700 ring-1 ring-red-600/20",
    # Paquete states
    "recibido" => "bg-sky-50 text-sky-700 ring-1 ring-sky-600/20",
    "etiquetado" => "bg-indigo-50 text-indigo-700 ring-1 ring-indigo-600/20",
    "en_manifiesto" => "bg-purple-50 text-purple-700 ring-1 ring-purple-600/20",
    "enviado" => "bg-violet-50 text-violet-700 ring-1 ring-violet-600/20",
    "en_bodega_hn" => "bg-teal-50 text-teal-700 ring-1 ring-teal-600/20",
    "pre_facturado" => "bg-cyan-50 text-cyan-700 ring-1 ring-cyan-600/20",
    # Manifiesto states
    "creado" => "bg-blue-50 text-blue-700 ring-1 ring-blue-600/20",
    "recibido_manifiesto" => "bg-green-50 text-green-700 ring-1 ring-green-600/20"
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
    COLORS[@status] || "bg-gray-50 text-gray-600 ring-1 ring-gray-500/20"
  end
end
