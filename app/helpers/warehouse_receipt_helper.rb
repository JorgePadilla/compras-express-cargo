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
    pieces      = paquetes.size
    weight_lb   = paquetes.sum { |p| p.peso.to_f }
    vol_lb      = paquetes.sum { |p| p.peso_volumetrico.to_f }
    volume_in3  = paquetes.sum do |p|
      (p.alto.to_f * p.largo.to_f * p.ancho.to_f)
    end
    volume_cuft = volume_in3 * IN3_TO_FT3

    # ── El total de libras que se le va a cobrar ────────────────────────────
    #
    # Yusef, audio del 2026-08-13: *"el valor total de libras que se le va a
    # cobrar. **No es valor de precios, sino es valor de libras** que se le va a
    # cobrar, el que sea mayor en cada transacción. O sea, si una caja pesa más y
    # la otra tiene más volumen, entonces le vas poniendo el de mayor **de cada
    # una individual**."*
    #
    # O sea: **suma de los máximos por caja**, no el máximo de las sumas. No dan
    # lo mismo — con una caja de 5 lb (4.5 vol) y otra de 2 lb (163 vol), sumar
    # los máximos da 177.0 y comparar los totales da 176.5.
    #
    # `peso_cobrar` es esa columna: `calculate_peso_cobrar` ya la persiste por
    # caja con la regla completa (incluido el trato de solo-volumétrico del
    # cliente). Se **suma**, no se recalcula: reimplementar la regla acá sería
    # recrear la duplicación que `PR-C7.11` vino a matar.
    cobrar_lb = paquetes.sum { |p| p.peso_cobrar.to_f }

    {
      pieces:        pieces,
      weight_lb:     weight_lb.round(2),
      weight_kg:     (weight_lb * LB_TO_KG).round(2),
      vol_weight_lb: vol_lb.round(2),
      vol_weight_kg: (vol_lb * LB_TO_KG).round(2),
      chargeable_lb: cobrar_lb.round(2),
      chargeable_kg: (cobrar_lb * LB_TO_KG).round(2),
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

  # Texto T&C para el WR. Consulta el modelo `Term` cuando hay una version
  # asociada al WR; cae a las constantes inline (defensive) si no hay
  # ninguna fila activa para el idioma pedido.
  def wr_terms(language: :es, version: nil)
    if version.present?
      from_db = Term.body_for(version: version, language: language.to_s)
      return from_db if from_db.present?
    end
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

  # Defaults inline — si el initializer no se cargó (typical en dev sin
  # restart), no rompemos la página. El initializer puede sobrescribirlos.
  WR_ISSUING_COMPANY_DEFAULT = {
    name:        "COMPRAS EXPRESS LOGISTICS LLC",
    street:      "8109 NW 60th STREET",
    city:        "Miami",
    state:       "Florida",
    postal_code: "33195-3415",
    country:     "USA",
    phone:       "+1 305-848-0990",
    website:     "https://www.comprasexpresshn.com"
  }.freeze
  WR_TERMS_VERSION_DEFAULT = "2026-01".freeze

  # Atajo al hash de la empresa emisora del WR (US LLC). Cae a defaults
  # inline si el initializer no está cargado.
  def wr_issuing_company
    cfg = Rails.application.config.x.warehouse_receipt rescue nil
    return WR_ISSUING_COMPANY_DEFAULT if cfg.nil? || cfg.issuing_company.nil?
    WR_ISSUING_COMPANY_DEFAULT.merge(cfg.issuing_company.to_h)
  end

  def wr_terms_version
    cfg = Rails.application.config.x.warehouse_receipt rescue nil
    cfg&.terms_version || WR_TERMS_VERSION_DEFAULT
  end
end
