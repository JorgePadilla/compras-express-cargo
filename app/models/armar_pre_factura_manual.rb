# PR-P.10 · La pre-factura **a mano** (`/pre_facturas/new`), la puerta de las
# excepciones.
#
# Jorge, el 2026-10-10: *"the old prefactura now doesn't make a lot of
# sense"*. Desde la Fase 14 lo normal es «Preparar pre-factura» → «Auditar» →
# F9, que cobra por el **volumen** medido (`ArmarPreFacturaPorVolumen`). La
# puerta a mano se queda para lo que el escaneo no cubre —prepagado en Miami,
# una tanda con tarifas mezcladas (`RP-92`), un paquete que nunca se midió o
# sin manifiesto oficial, volver a pre-facturar después de anular—, pero hasta
# acá cobraba **todo** por paquete con el peso de Miami, aunque el paquete
# tuviera un volumen medido. Dos puertas, dos cobros distintos para la misma
# caja.
#
# La regla:
#
# - Un paquete de una tanda medida (`medicion_sesion` con sus `Bulto`) trae
#   **su tanda entera** y la tanda se cobra por volumen. No se elige media
#   tanda: el volumen pesó todo lo que tiene adentro.
# - Si `ArmarPreFacturaPorVolumen` rechaza la tanda (prepagada en Miami,
#   tarifas distintas, una caja trabada o de otro cliente), las cajas que se
#   eligieron van **por paquete**, como siempre, y el motivo se dice.
# - Lo que no tiene tanda, por paquete, como siempre.
#
# Para decidir si una tanda va por volumen **se le pregunta al armador por
# volumen**, tanda por tanda: sus guardas no se copian acá, así que no se
# pueden separar. Y la plata no se toca: las líneas de volumen son las de
# `ArmarPreFacturaPorVolumen` y las de paquete las de
# `PreFactura#agregar_lineas_por_paquete`, que es `build_from_paquetes`.
#
# Los cargos automáticos (recolecta, cambio de servicio) salen **una vez por
# caja**: los de las tandas los pone el armador por volumen y los del resto
# `agregar_lineas_por_paquete`, sobre conjuntos de cajas que no se tocan.
#
# Devuelve la `PreFactura` **sin guardar**: la usan el preview de la pantalla y
# el `create`, y por eso lo que la pantalla muestra es lo que se guarda.
class ArmarPreFacturaManual
  # `por_volumen`: las tandas que se cobran por volumen. `rechazos`: las que se
  # cobran por paquete, con el porqué (`{ sesion => motivo }`).
  Resultado = Struct.new(:pre_factura, :por_volumen, :rechazos, keyword_init: true) do
    def por_volumen?(paquete) = por_volumen.include?(paquete.medicion_sesion)
    def rechazo_de(paquete) = paquete.medicion_sesion && rechazos[paquete.medicion_sesion]

    # Las líneas que cobran la tanda (una por volumen) y sus cajas en L. 0.00.
    def lineas_de_volumen(sesion) = items.select { |i| i.origen == "volumen" && i.bulto&.sesion == sesion }
    def cajas_de_la_tanda(sesion)
      items.select { |i| i.origen == "caja_del_volumen" && i.bulto&.sesion == sesion }.map(&:paquete)
    end

    # La línea de flete de un paquete que va por paquete (o su simbólico).
    def flete_de(paquete) = items.find { |i| i.origen == "manual" && i.paquete_id == paquete.id }

    private

    def items = pre_factura.pre_factura_items
  end

  def self.call(...) = new(...).call

  def initialize(cliente:, paquete_ids:, user: nil)
    @cliente = cliente
    @paquete_ids = Array(paquete_ids)
    @user = user
  end

  def call
    # Igual que `build_from_paquetes`: un id que no es facturable del cliente
    # no entra, aunque lo manden.
    elegidos = @cliente.paquetes.facturables.where(id: @paquete_ids).to_a
    rechazos = {}
    tandas = elegidos.filter_map(&:medicion_sesion).uniq.select { |sesion| Bulto.de_la_sesion(sesion).exists? }
    por_volumen = tandas.select { |sesion| va_por_volumen?(sesion, rechazos) }

    pre_factura = if por_volumen.any?
      ArmarPreFacturaPorVolumen.call(cliente: @cliente, sesiones: por_volumen, user: @user)
    else
      PreFactura.new(cliente: @cliente, creado_por: @user, fecha_trabajo: Date.current)
    end

    sueltos = elegidos.reject { |p| por_volumen.include?(p.medicion_sesion) }.map(&:id)
    pre_factura.agregar_lineas_por_paquete(
      @cliente.paquetes.facturables.where(id: sueltos).includes(:tipo_envio, :sucursal, :proveedor)
    )

    Resultado.new(pre_factura: pre_factura, por_volumen: por_volumen, rechazos: rechazos)
  end

  private

  # Se arma la tanda sola y se tira: si el armador por volumen la acepta, va
  # por volumen; si no, su motivo es el que se le muestra al cajero.
  def va_por_volumen?(sesion, rechazos)
    ArmarPreFacturaPorVolumen.call(cliente: @cliente, sesiones: [ sesion ], user: @user)
    true
  rescue ArmarPreFacturaPorVolumen::NoSePuede => e
    rechazos[sesion] = e.message
    false
  end
end
