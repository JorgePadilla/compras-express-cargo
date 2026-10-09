require "test_helper"

# C24-01 · La excepción de cobro de un paquete.
#
# Yusef, 2026-09-05: *"Tengo un cliente que me ha movido unos **generadores** […]
# Estos eran **400 libras**. Pero **el volumen de esos es 150 libras**. Es lo que
# yo […] voy a cobrar."*
#
# Los números de este archivo son los suyos.
class MarcarCobroExcepcionTest < ActiveSupport::TestCase
  setup do
    @supervisor = users(:supervisor_prefactura)
    @supervisor.update!(pin: "1234")

    @paquete = paquetes(:recibido)
    # 400 lb reales, 150 volumétricas. `peso_volumetrico` se escribe con
    # `update_columns` porque el `before_save` lo recalcularía desde las medidas.
    @paquete.update!(peso: 400, alto: nil, largo: nil, ancho: nil,
                     tipo_envio: tipo_envios(:express),
                     pre_factura_id: nil, venta_id: nil)
    @paquete.update_columns(peso_volumetrico: 150, peso_cobrar: 400, cobro_excepcion: nil)
    @paquete.reload
  end

  # ── El caso de Yusef ─────────────────────────────────────────────────────

  test "sin excepción el generador cobra las 400 libras reales" do
    @paquete.save!

    assert_equal 400, @paquete.reload.peso_cobrar.to_i
  end

  test "con la excepción cobra las 150 volumétricas, que es el MENOR" do
    marcar!

    assert_equal 150, @paquete.reload.peso_cobrar.to_i,
                 "es al revés de la regla normal: acá gana el menor"
  end

  test "quitarle la excepción devuelve las 400" do
    marcar!
    assert_equal 150, @paquete.reload.peso_cobrar.to_i

    marcar!(excepcion: nil, motivo: "no era ese cliente")

    assert_equal 400, @paquete.reload.peso_cobrar.to_i
    assert_nil @paquete.cobro_excepcion
  end

  # ── Que no se rompa `PR-C6.41` ───────────────────────────────────────────
  #
  # El flag por **cliente × tipo de envío** sigue vivo: una cosa es *"a este
  # cliente, en este servicio, siempre"* y otra *"a este paquete, esta vez"*.

  test "sin excepción del paquete, el trato del cliente sigue mandando" do
    ClienteCobroVolumetrico.create!(cliente: @paquete.cliente, tipo_envio: @paquete.tipo_envio)

    @paquete.reload.save!

    assert_equal 150, @paquete.reload.peso_cobrar.to_i,
                 "el trato del cliente no se tocó"
  end

  test "la excepción del paquete no necesita que el cliente tenga el trato" do
    assert_not @paquete.cliente.cobra_solo_volumetrico?(@paquete.tipo_envio_id)

    marcar!

    assert_equal 150, @paquete.reload.peso_cobrar.to_i
  end

  # ── El registro, que es el punto del control que pidió Yusef ─────────────

  test "deja registro de quién, qué y por qué" do
    autorizacion = marcar!(motivo: "generadores, se cobran por volumen")

    assert_equal "cobro_excepcion", autorizacion.accion
    assert_equal @supervisor, autorizacion.autorizado_por
    assert_equal @paquete, autorizacion.documento
    assert_equal "generadores, se cobran por volumen", autorizacion.motivo
    assert_equal 400, autorizacion.valor_anterior.to_i
    assert_equal 150, autorizacion.valor_nuevo.to_i, "el peso nuevo se captura después de aplicar"
  end

  # Sale en `/autorizaciones` sin tocar la bitácora: es el mismo modelo.
  test "aparece en la bitácora junto con las autorizaciones de línea" do
    autorizacion = marcar!

    assert_includes Autorizacion.recientes.to_a, autorizacion
  end

  # ── Lo que NO deja hacer ─────────────────────────────────────────────────

  test "un usuario sin rol autorizante no puede" do
    cajero = users(:cajero)
    cajero.update!(pin: "1234")

    assert_raises(MarcarCobroExcepcion::NoPermitido) { marcar!(supervisor: cajero) }
    assert_nil @paquete.reload.cobro_excepcion
  end

  test "un supervisor sin PIN cargado tampoco" do
    @supervisor.update_columns(pin_digest: nil)

    assert_raises(MarcarCobroExcepcion::NoPermitido) { marcar! }
  end

  # El PIN lo valida `Autorizacion` con sus propias reglas — acá se afirma que
  # el rechazo **deja el paquete intacto**, que es lo que importa.
  test "con el PIN equivocado no cambia nada" do
    assert_raises(ActiveRecord::RecordInvalid) { marcar!(pin: "9999") }

    assert_nil @paquete.reload.cobro_excepcion
    assert_equal 400, @paquete.peso_cobrar.to_i
  end

  test "sin motivo no se puede: es el punto del registro" do
    assert_raises(MarcarCobroExcepcion::SinMotivo) { marcar!(motivo: "  ") }

    assert_nil @paquete.reload.cobro_excepcion
  end

  test "una excepción que no existe se rechaza" do
    assert_raises(ArgumentError) { marcar!(excepcion: "por_las_ganas") }
  end

  # Cambiarle el peso a un paquete ya facturado movería un documento cerrado por
  # atrás. Mismo guard que `QuitarCambioServicio`.
  test "un paquete ya facturado no admite la excepción" do
    @paquete.update_columns(venta_id: ventas(:pendiente_juan).id)

    assert_raises(MarcarCobroExcepcion::YaFacturado) { marcar! }
    assert_nil @paquete.reload.cobro_excepcion
  end

  # ── Que llegue a la pre-factura, que es lo que Yusef pidió ───────────────
  #
  # *"Que lo tengamos **previsto** en prefactura."* El cotizador recibe
  # `paquete.peso_cobrar` sin medidas, así que la línea hereda las 150 **sin que
  # se toque nada de pre-factura**.

  test "la línea de pre-factura nace con las 150" do
    marcar!
    # `build_from_paquetes` solo toma los facturables. Va con `update_columns`
    # porque la fixture trae tareas abiertas y el guard de estado las respeta —
    # y acá lo que se prueba es el peso, no el pipeline.
    @paquete.update_columns(estado: "en_aduana")

    pre_factura = PreFactura.build_from_paquetes(@paquete.cliente, [ @paquete.id ])
    linea = pre_factura.pre_factura_items.find { |i| i.paquete_id == @paquete.id }

    assert_equal 150, linea.peso_cobrar.to_i,
                 "no se tocó nada de pre-factura: hereda el peso del paquete"
  end

  # ── El espejo: cobrar el peso real aunque gane el volumétrico ────────────
  #
  # Jorge, 2026-09-06, aclarando lo que Yusef pidió: *"él quiere poder cobrar
  # **por libra o volumen volumétrico de vez en cuando, dependiendo el caso**"*.
  # Son las dos mitades de lo mismo, no dos funciones distintas.

  test "con solo_peso cobra el real aunque el volumétrico sea mayor" do
    # Al revés del caso de los generadores: 100 reales contra 500 volumétricas.
    @paquete.update_columns(peso: 100, peso_volumetrico: 500, peso_cobrar: 500)

    marcar!(excepcion: "solo_peso", motivo: "carga liviana y voluminosa, se cobra por libra")

    assert_equal 100, @paquete.reload.peso_cobrar.to_i
  end

  # **La excepción del paquete le gana al trato del cliente**, que es lo que
  # Yusef pidió con *"exclusivamente esa"*. Sin esta precedencia, un cliente con
  # el flag de `PR-C6.41` no podría tener nunca un paquete cobrado por peso.
  test "solo_peso le gana al trato de volumen del cliente" do
    ClienteCobroVolumetrico.create!(cliente: @paquete.cliente, tipo_envio: @paquete.tipo_envio)

    marcar!(excepcion: "solo_peso", motivo: "esta vez por libra")

    assert_equal 400, @paquete.reload.peso_cobrar.to_i,
                 "el paquete manda sobre el cliente"
  end

  test "el registro dice cuál de las dos excepciones fue" do
    autorizacion = marcar!(excepcion: "solo_peso", motivo: "por libra")

    assert_match(/peso real/i, autorizacion.detalle)
    assert_no_match(/en vez del real/i, autorizacion.detalle)
  end

  private

  def marcar!(excepcion: "solo_volumetrico", supervisor: @supervisor,
              pin: "1234", motivo: "el caso de los generadores")
    MarcarCobroExcepcion.new(paquete: @paquete, excepcion: excepcion,
                             supervisor: supervisor, pin: pin, motivo: motivo).call
  end
end
