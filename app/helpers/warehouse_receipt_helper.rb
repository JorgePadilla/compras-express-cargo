# Helpers para el render del Warehouse Receipt (`paquetes/label.html.erb`).
# Mantiene conversiones de unidades, totales agregados, T&C bilingüe e
# iniciales de usuario fuera del template para que el HTML sea simple.
module WarehouseReceiptHelper
  LB_TO_KG       = 0.4535924
  CUFT_TO_M3     = 0.0283168
  VOL_DIVISOR_LB = 166.0   # in³ → lb (default cargo aéreo)
  IN3_TO_FT3     = 1.0 / 1728.0

  # Lista de paquetes que componen el WR. Si el paquete está dividido
  # (split en N cajas), incluye sus hermanos; si no, solo a sí mismo.
  # Ordena por `numero_caja` para una presentación estable.
  def wr_packages_for(paquete)
    return [ paquete ] unless paquete.dividido?
    [ paquete, *paquete.paquetes_hermanos ].sort_by { |p| p.numero_caja.to_i }
  end

  # Totales agregados por colección de paquetes.
  # Devuelve un hash con: pieces, weight_lb, weight_kg, vol_weight_lb,
  # vol_weight_kg, volume_cuft, volume_m3.
  def wr_totals(paquetes)
    pieces      = paquetes.sum { |p| (p.numero_caja.to_i.zero? ? 1 : 1) }
    weight_lb   = paquetes.sum { |p| p.peso.to_f }
    vol_lb      = paquetes.sum { |p| p.peso_volumetrico.to_f }
    volume_in3  = paquetes.sum do |p|
      (p.alto.to_f * p.largo.to_f * p.ancho.to_f)
    end
    volume_cuft = volume_in3 * IN3_TO_FT3

    {
      pieces:        pieces,
      weight_lb:     weight_lb.round(2),
      weight_kg:     (weight_lb * LB_TO_KG).round(2),
      vol_weight_lb: vol_lb.round(2),
      vol_weight_kg: (vol_lb * LB_TO_KG).round(2),
      volume_cuft:   volume_cuft.round(2),
      volume_m3:     (volume_cuft * CUFT_TO_M3).round(4)
    }
  end

  # Iniciales del usuario en formato "Y.G." (max 2 letras + punto cada una).
  def wr_user_initials(user)
    return "—" unless user
    source = if user.respond_to?(:nombre) && user.nombre.to_s.strip.present?
               user.nombre.to_s
             else
               user.email_address.to_s.split("@").first.to_s
             end
    parts = source.split(/[\s._-]+/).reject(&:blank?)
    return "—" if parts.empty?
    parts.first(2).map { |w| "#{w[0].to_s.upcase}." }.join
  end

  # Texto T&C bilingüe genérico inicial. Versionado via
  # `Rails.application.config.x.warehouse_receipt.terms_version` (2026-01).
  # Cuando se cree el modelo `Terms` (PR-D5) este helper consultará la fila
  # activa para la versión congelada del WR.
  def wr_terms(language: :es)
    case language.to_sym
    when :en then WR_TERMS_EN
    else          WR_TERMS_ES
    end
  end

  WR_TERMS_ES = <<~ES.strip.freeze
    1. La empresa transportará la mercancía descrita en este recibo bajo las condiciones aquí establecidas.
    2. El cliente declara que la información del contenido es verídica. La empresa no se responsabiliza por declaraciones falsas o incompletas.
    3. Los pesos y dimensiones son verificados al recibir; la facturación final usa el peso facturable mayor entre real y volumétrico.
    4. La mercancía no reclamada en un plazo de 30 días naturales se considerará abandonada.
    5. La empresa no se hace responsable de daños por embalaje insuficiente, mercancía prohibida o contenido perecedero.
    6. La firma o aceptación electrónica de este recibo constituye conformidad con los términos.
  ES

  WR_TERMS_EN = <<~EN.strip.freeze
    1. The carrier shall transport the merchandise described herein under the conditions set forth.
    2. The customer warrants that the content information is true and accurate. Carrier is not liable for false or incomplete declarations.
    3. Weights and dimensions are verified upon receipt; billing uses the chargeable weight (greater of actual and volumetric).
    4. Goods unclaimed within 30 calendar days will be deemed abandoned.
    5. Carrier shall not be liable for damages caused by insufficient packaging, prohibited items, or perishable content.
    6. Signature or electronic acceptance of this receipt constitutes agreement with the terms.
  EN

  # Atajo al hash de la empresa emisora del WR (US LLC) para usar en la vista.
  def wr_issuing_company
    Rails.application.config.x.warehouse_receipt.issuing_company
  end

  def wr_terms_version
    Rails.application.config.x.warehouse_receipt.terms_version
  end
end
