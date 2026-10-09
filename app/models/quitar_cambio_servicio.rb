# Quitarle a un paquete el cobro por cambio de servicio, con el PIN de un
# supervisor.
#
# PR-C6.28. Yusef, 2026-08-08:
#
#   > "Aquí es donde hay un dilema: si el muchacho mío se equivocó y lo está
#   >  cambiando, tenemos que buscar una manera de **poderle quitar ese cambio
#   >  de servicio**. Eso sería como que le digan al **supervisor** de ellos
#   >  allá en Miami: 'hey, mire, yo me equivoqué, lo ingresé mal y era otro
#   >  tipo de envío', y entonces él lo pueda eliminar el cobro."
#   > "No estamos hablando de Jordan o Julio, sino que él se llama **Julien**,
#   >  el supervisor… que él sí pueda eliminarlo **con el usuario de él**."
#
# ── Por qué apaga el flag y no borra la línea ─────────────────────────────
#
# El cobro nace en DOS lugares independientes:
#
#   1. la línea automática de la pre-factura (`origen: "auto_servicio_extra"`)
#   2. una **NotaDebito aparte**, que `PreFactura#facturar!` genera leyendo
#      `paquete.solicito_cambio_servicio?` — no la línea
#
# La vía que ya existía (autorización con PIN → `item.destroy!`) borra la
# línea y **deja viva la NotaDebito**: el cliente igual termina pagando. Por
# eso el origen del cobro es el flag, y es el flag lo que hay que apagar.
#
# ── Por qué no se usa `ROLES_AUTORIZANTES` ────────────────────────────────
#
# Agregar `supervisor_miami` a esa lista le daría autorización sobre
# **cualquier** línea de pre-factura — precios, descuentos, todo. Yusef pidió
# una cosa puntual. Este flujo tiene su propia lista, corta a propósito.
class QuitarCambioServicio
  # Quién puede. `admin` porque puede todo; `supervisor_miami` porque es el
  # rol de Julien, que es a quien el digitador le va a pedir el favor.
  ROLES = %w[admin supervisor_miami].freeze

  class NoPermitido   < StandardError; end
  class PinInvalido   < StandardError; end
  class YaFacturado   < StandardError; end

  def initialize(paquete:, supervisor:, pin:, motivo: nil)
    @paquete = paquete
    @supervisor = supervisor
    @pin = pin.to_s
    @motivo = motivo.to_s
  end

  def call
    validar!

    # `paper_trail` registra el cambio del flag con el usuario que lo hizo
    # (PR-C6.30 arregló el `whodunnit`, que venía nil), así que no hace falta
    # una bitácora aparte: el "quién apagó este cobro" ya queda.
    ActiveRecord::Base.transaction do
      borrar_linea_automatica
      @paquete.update!(solicito_cambio_servicio: false)
    end

    true
  end

  private

  def validar!
    raise NoPermitido, "Ese usuario no puede quitar el cobro." unless autorizado?
    raise PinInvalido, "PIN incorrecto." unless @supervisor.authenticate_pin(@pin)
    raise YaFacturado, facturado_msg if ya_facturado?
  end

  def autorizado?
    @supervisor.present? && @supervisor.activo? &&
      @supervisor.pin_digest.present? && @supervisor.tiene_rol?(ROLES)
  end

  # Una vez facturado, el cobro ya salió en un documento fiscal: sacarlo es
  # una nota de crédito, no un flag. Queda fuera de alcance a propósito.
  def ya_facturado?
    @paquete.pre_factura&.facturado? || @paquete.venta_id.present?
  end

  def facturado_msg
    "Este paquete ya se facturó — el cobro se saca con una nota de crédito, no desde acá."
  end

  # Solo la línea AUTOMÁTICA, y solo si la pre-factura sigue abierta. Una
  # línea que el cajero escribió a mano no la toca este flujo.
  def borrar_linea_automatica
    pf = @paquete.pre_factura
    return 0 if pf.nil? || pf.facturado?

    lineas = pf.pre_factura_items
               .where(paquete_id: @paquete.id, origen: "auto_servicio_extra")
               .joins(:servicio_extra)
               .where(servicios_extra: { codigo: "CAMBIO_SERVICIO" })

    borradas = lineas.count
    lineas.destroy_all
    # Los totales viven en `pre_factura` y se recalculan en su `before_save`,
    # que no corre al destruir un item suelto.
    pf.reload.save! if borradas.positive?
    borradas
  end
end
