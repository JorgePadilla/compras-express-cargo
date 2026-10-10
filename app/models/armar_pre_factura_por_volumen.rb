# PR-P.1 · La línea de la factura es **el volumen** (Fase 14, `C27-10`,
# `C27-15`, `RP-41`).
#
# `PreFactura.build_from_paquetes` arma una línea de flete **por caja** con el
# `peso_cobrar` de la caja, que es el peso de Miami: la pre-factura nunca leía
# lo que Medición pesó. Acá la línea es el **volumen** —el `Bulto`, lo que el
# operario pesó y midió junto en la PESA— con su `peso_cobrar`, y cada caja de
# la tanda va en L. 0.00 debajo. Yusef, el 2026-09-07: *"le decimos: mire, le
# valió tanto, sale de esto más esto"*. Un volumen de tres cajas cobra **un**
# mínimo, no tres.
#
# **La cadena de la plata no se toca** (redondeo → escalón → mínimo → ISV):
# cambia lo que entra, no cómo se calcula. El volumen se cotiza con
# `CotizadorFlete` (→ `Tarifa.resolver` → `cobro_para`) y se pasa a la moneda
# del documento con `LineasDeFlete.montos_en_moneda`, que son el mismo motor
# que `build_from_paquetes` y las notas: hay un test que exige que un volumen
# y una caja suelta del mismo peso cobren lo mismo.
#
# Las cajas en L. 0.00 son lo que hace que el resto no cambie: `confirmar!`,
# `facturar!`, `anular!` y `vincular_paquetes` encuentran sus paquetes por
# `has_many :paquetes, through: :pre_factura_items`, como siempre. Llevan
# `minimo_aplicado` para que nadie les recalcule `peso × precio`, y cuelgan del
# primer volumen de su tanda: desde C28-08 una caja es **de la tanda**, no de
# un volumen, y así la línea sabe su tanda sin otra columna.
#
# **Dormido**: ninguna pantalla lo llama todavía (`PR-P.5` lo conecta). Lo que
# queda afuera del flujo por escaneo —prepagado en Miami, tarifas especiales—
# sigue por `/pre_facturas/new`, y acá se rechaza en vez de cobrarse a medias.
#
# Devuelve la `PreFactura` **sin guardar**, como `build_from_paquetes`: el que
# la llama decide cuándo.
class ArmarPreFacturaPorVolumen
  include LineasDeFlete

  class NoSePuede < StandardError; end

  def self.call(...) = new(...).call

  # `sesiones` son una o varias tandas de Medición (`paquetes.medicion_sesion`,
  # que es la `sesion` de sus bultos).
  def initialize(cliente:, sesiones:, user: nil)
    @cliente = cliente
    @sesiones = Array(sesiones).map(&:to_s).compact_blank.uniq
    @user = user
  end

  def call
    raise NoSePuede, "No hay ninguna tanda medida que facturar." if @sesiones.empty?

    tandas = @sesiones.map { |sesion| tanda(sesion) }
    pre_factura = PreFactura.new(cliente: @cliente, creado_por: @user, fecha_trabajo: Date.current)

    tandas.each do |bultos, cajas|
      bultos.each { |bulto| pre_factura.pre_factura_items.build(linea_del_volumen(pre_factura, bulto, cajas)) }
      cajas.each do |caja|
        pre_factura.pre_factura_items.build(
          paquete: caja, bulto: bultos.first,
          concepto: "#{caja.guia} · #{incluida_en(bultos)}",
          subtotal: BigDecimal("0"),
          # Sin peso ni precio, y con el guard puesto: el cobro está en el
          # volumen, y una caja que se recalculara sola cobraría dos veces.
          minimo_aplicado: true,
          origen: "caja_del_volumen"
        )
      end
    end

    # PR-D6.b · Los cargos automáticos siguen siendo **por caja**: la recolecta
    # y el cambio de servicio son de cada paquete, no del volumen.
    tandas.flat_map(&:last).each { |caja| pre_factura.aplicar_cobros_automaticos_para(caja) }

    pre_factura
  end

  private

  # Los volúmenes y las cajas de una tanda, con las guardas que hacen que el
  # peso del volumen sea cobrable: si una caja de la tanda no puede entrar al
  # documento, el volumen pesa algo que no se le está facturando.
  def tanda(sesion)
    bultos = Bulto.de_la_sesion(sesion).to_a
    raise NoSePuede, "La tanda #{sesion} ya no tiene volúmenes: se midió de nuevo. Escaneá otra vez." if bultos.empty?

    cajas = Paquete.where(medicion_sesion: sesion).includes(:tipo_envio, :sucursal, :proveedor).order(:id).to_a
    raise NoSePuede, "La tanda #{sesion} no tiene cajas." if cajas.empty?

    ajenas = cajas.reject { |c| c.cliente_id == @cliente.id }
    raise NoSePuede, "#{codigos(ajenas)} no es de #{@cliente.nombre_completo}." if ajenas.any?

    libres = @cliente.paquetes.facturables.where(id: cajas.map(&:id)).pluck(:id).to_set
    trabadas = cajas.reject { |c| libres.include?(c.id) }
    if trabadas.any?
      raise NoSePuede, "#{codigos(trabadas)} no se puede facturar (ya está en una pre-factura, o todavía no " \
                       "llegó a Honduras). El volumen pesa con ella adentro: no se cobra a medias."
    end

    prepagadas = cajas.select(&:prepagado_miami?)
    if prepagadas.any?
      raise NoSePuede, "#{codigos(prepagadas)} viene prepagada en Miami: esa pre-factura se hace por " \
                       "Pre-Facturas › Nueva, que pone el cobro simbólico."
    end

    [ bultos, cajas ]
  end

  # La línea que cobra: `CotizadorFlete` sobre el `peso_cobrar` del volumen,
  # **sin medidas** —como las notas (`LineasDeFlete`)—: el volumétrico ya lo
  # resolvió el bulto, y el cotizador lo toma tal cual.
  def linea_del_volumen(pre_factura, bulto, cajas)
    tipo_envio = cajas.first.tipo_envio
    peso = bulto.peso_cobrar || BigDecimal("0")
    misma_tarifa!(bulto, cajas, tipo_envio, peso)

    cotizacion = CotizadorFlete.call(tipo_envio: tipo_envio, cliente: @cliente,
                                     proveedor: cajas.first.proveedor, sucursal: cajas.first.sucursal,
                                     peso: peso)
    precio, subtotal = self.class.send(:montos_en_moneda, cotizacion, pre_factura.moneda)

    { bulto: bulto, concepto: concepto_del_volumen(bulto, cajas, tipo_envio, cotizacion),
      peso_cobrar: cotizacion.peso_facturado, precio_libra: precio, subtotal: subtotal,
      minimo_aplicado: cotizacion.aplico_minimo, origen: "volumen" }
  end

  # «NO Mezclar» (`PuedenIrJuntas`) garantiza el mismo cliente y el mismo
  # servicio en la tanda, pero no el mismo proveedor ni la misma sucursal, y
  # `Tarifa.resolver` mira los dos. Si las cajas de un volumen cotizarían con
  # tarifas distintas, no hay **una** tarifa que ponerle: se para acá en vez
  # de cobrar con la de la primera.
  def misma_tarifa!(bulto, cajas, tipo_envio, peso)
    tarifas = cajas.map { |c| [ c.proveedor, c.sucursal ] }.uniq.map do |proveedor, sucursal|
      Tarifa.resolver(tipo_envio: tipo_envio, peso: peso, cliente: @cliente, proveedor: proveedor, sucursal: sucursal)
    end
    return if tarifas.uniq.size <= 1

    raise NoSePuede, "Las cajas del volumen #{bulto.de_cuantos_texto || bulto.orden} se cobran con tarifas " \
                     "distintas (proveedor o sucursal): esa pre-factura se hace por Pre-Facturas › Nueva."
  end

  # Las mismas marcas que `build_from_paquetes` —«(mínimo de servicio)» y
  # «⚠ SIN TARIFA CARGADA»—, para que se lean igual en las dos.
  def concepto_del_volumen(bulto, cajas, tipo_envio, cotizacion)
    servicio = tipo_envio&.nombre
    volumen = [ "Volumen", bulto.de_cuantos_texto ].compact.join(" ")
    detalle = "#{volumen} · #{cajas.size} caja#{"s" if cajas.size != 1}"
    return "⚠ SIN TARIFA CARGADA — #{servicio || 'servicio'} - #{detalle}" if cotizacion.sin_tarifa

    concepto = "Flete #{servicio || 'Paquete'} - #{detalle}"
    concepto += " (mínimo de servicio)" if cotizacion.aplico_minimo
    concepto
  end

  def incluida_en(bultos)
    bultos.size == 1 ? "incluida en el volumen" : "incluida en la tanda de #{bultos.size} volúmenes"
  end

  def codigos(cajas) = cajas.map { |c| c.numero_recepcion_visible.presence || c.tracking }.join(", ")
end
