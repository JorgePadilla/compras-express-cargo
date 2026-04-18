class PreAlertaCardComponent < ViewComponent::Base
  def initialize(pre_alerta:)
    @pre_alerta = pre_alerta
  end

  private

  attr_reader :pre_alerta

  def tipo_envio_badge_text
    pre_alerta.tipo_envio.nombre
  end

  def tipo_envio_description
    pre_alerta.tipo_envio_descripcion
  end

  def consolidation_badge
    if pre_alerta.finalizado?
      { text: "Consolidado Finalizado", bg: "bg-cec-teal/10", text_color: "text-cec-teal-dark", ring: "ring-cec-teal/30" }
    elsif pre_alerta.consolidando?
      { text: "Consolidando", bg: "bg-cec-gold/10", text_color: "text-cec-gold-dark", ring: "ring-cec-gold/30" }
    else
      { text: "Sin Consolidar", bg: "bg-red-50", text_color: "text-red-700", ring: "ring-red-600/20" }
    end
  end

  def info_line
    parts = []
    parts << pre_alerta.proveedor if pre_alerta.proveedor.present?
    parts << pre_alerta.numero_documento
    parts << pre_alerta.created_at.strftime("%d/%m/%Y")
    parts.join(" · ")
  end
end
