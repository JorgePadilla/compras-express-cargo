# Bajar la cantidad de cajas de un split cuando alguna ya entró a cobro, con
# el PIN de un supervisor.
#
# PR-C6.42 · RP-18. Yusef marcó ☒ *"Que deje hacerlo, pero solo con PIN de
# supervisor"*, y en el audio dio el caso real:
#
#   > "Le pusieron 2 y al final es un paquete, y cuando van a entregar, el
#   >  sistema no va a querer entregar porque decía que eran dos."
#
# Hoy `Paquete.ajustar_split!` levanta `CajaNoEliminable` en cuanto una caja
# sobrante tocó una pre-factura o una entrega. Esa guarda es correcta —borrar
# una caja cobrada descuadraría la venta en silencio— pero **deja el paquete
# trabado**: la caja fantasma no existe físicamente, así que nadie la va a
# entregar nunca, y el tracking entero se queda sin poder cerrarse.
#
# ── Lo que este flujo SÍ desengancha ──────────────────────────────────────
#
# Borrar la caja a secas no alcanza: `pre_factura_items` y `venta_items`
# apuntan al paquete con FK, así que el `destroy!` reventaría contra la base.
# Antes de borrar hay que sacar la caja fantasma de la pre-factura abierta y
# de la entrega, y recalcular los totales — si no, el cliente sigue pagando
# una caja que ya no existe.
#
# ── Dónde se planta el límite ─────────────────────────────────────────────
#
# Igual que `QuitarCambioServicio`: una vez que el cobro salió en un documento
# **fiscal** —pre-factura facturada, o venta— sacarlo es una nota de crédito,
# no un borrado. Lo mismo con una caja ya **entregada**: eso es un hecho
# físico, no un error de digitación. En esos casos ni el PIN alcanza.
class BajarCajasConPin
  # Quién puede. `admin` porque puede todo; `supervisor_miami` porque es donde
  # nace el error de digitación; los dos de facturación porque el daño que la
  # guarda protege es contable y son ellos los que lo van a ver.
  #
  # No se toca `User::ROLES_AUTORIZANTES`: esa lista da autorización sobre
  # cualquier línea de pre-factura, y esto es una cosa puntual. Quién lleva
  # cada PIN sigue abierto en `RP-21`.
  ROLES = %w[admin supervisor_miami supervisor_prefactura supervisor_caja].freeze

  class NoPermitido   < StandardError; end
  class PinInvalido   < StandardError; end
  class YaFacturado   < StandardError; end
  class NadaQueBajar  < StandardError; end

  def initialize(paquete:, cantidad:, supervisor:, pin:, motivo: nil)
    @paquete = paquete
    @cantidad = cantidad.to_i
    @supervisor = supervisor
    @pin = pin.to_s
    @motivo = motivo.to_s
  end

  # Devuelve las cajas que quedan.
  def call
    validar!

    ActiveRecord::Base.transaction do
      sobrantes.each { |caja| desenganchar(caja) }
      Paquete.ajustar_split!(@paquete, @cantidad, forzar: true)
    end
  end

  private

  def validar!
    raise NoPermitido, "Ese usuario no puede bajar la cantidad de cajas." unless autorizado?
    raise PinInvalido, "PIN incorrecto." unless @supervisor.authenticate_pin(@pin)
    raise NadaQueBajar, "La cantidad tiene que ser menor a las #{hermanas.size} cajas actuales." if @cantidad < 1 || @cantidad >= hermanas.size

    intocables = sobrantes.select { |c| intocable?(c) }
    raise YaFacturado, mensaje_intocables(intocables) if intocables.any?
  end

  def autorizado?
    @supervisor.present? && @supervisor.activo? &&
      @supervisor.pin_digest.present? && @supervisor.rol.in?(ROLES)
  end

  def hermanas
    @hermanas ||= Paquete.cajas_del_mismo_split(@paquete).to_a
  end

  def sobrantes
    @sobrantes ||= hermanas.select { |c| c.numero_caja.to_i > @cantidad }
  end

  # Lo que ni el PIN destraba: un documento fiscal ya emitido o una entrega
  # que de verdad ocurrió.
  def intocable?(caja)
    caja.venta_id.present? || caja.facturado? || caja.entregado? ||
      caja.pre_factura&.facturado? || VentaItem.exists?(paquete_id: caja.id)
  end

  def mensaje_intocables(cajas)
    detalle = cajas.map { |c| "la caja #{c.numero_caja}" }.join(", ")
    "No se puede bajar: #{detalle} ya se facturó o se entregó — eso se corrige " \
      "con una nota de crédito, no desde acá."
  end

  # Saca la caja fantasma de la pre-factura abierta y de la entrega. Sin esto
  # el `destroy!` choca contra la FK de `pre_factura_items`, y peor: si
  # chocara y alguien la borrara igual, el cliente seguiría pagando una caja
  # que ya no existe.
  #
  # `paper_trail` registra el borrado con el usuario que lo hizo (PR-C6.30
  # arregló el `whodunnit`), así que el "quién bajó esta caja" ya queda.
  def desenganchar(caja)
    pf = caja.pre_factura
    if pf.present? && !pf.facturado?
      borradas = pf.pre_factura_items.where(paquete_id: caja.id).destroy_all.size
      # Los totales viven en `pre_factura` y se recalculan en su `before_save`,
      # que no corre al destruir un item suelto.
      pf.reload.save! if borradas.positive?
    end

    caja.update_columns(pre_factura_id: nil, entrega_id: nil)
  end
end
