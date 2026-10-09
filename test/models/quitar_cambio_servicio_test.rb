require "test_helper"

# PR-C6.28: quitarle a un paquete el cobro por cambio de servicio, con el PIN
# de un supervisor de Miami.
#
# Yusef, 2026-08-08:
#
#   "Si el muchacho mío se equivocó y lo está cambiando, tenemos que buscar una
#    manera de poderle quitar ese cambio de servicio… que le digan al
#    **supervisor** de ellos allá en Miami: 'hey, mire, yo me equivoqué'. Y que
#    él lo pueda eliminar el cobro **con el usuario de él**."
#
# **La trampa, y por qué esto apaga el flag en vez de borrar la línea:** el
# cobro nace en DOS lugares independientes — la línea automática de la
# pre-factura, y una NotaDebito que `facturar!` genera leyendo
# `paquete.solicito_cambio_servicio?`, no la línea. La vía que ya existía
# (autorización con PIN → destruir la línea) dejaba viva la NotaDebito: el
# cliente igual terminaba pagando.
class QuitarCambioServicioTest < ActiveSupport::TestCase
  setup do
    @supervisor = users(:admin)
    @supervisor.update!(pin: "1234")
    @paquete = paquetes(:recibido)
    @paquete.update!(solicito_cambio_servicio: true)
  end

  test "el supervisor con su PIN apaga el cobro" do
    assert quitar.call
    assert_not @paquete.reload.solicito_cambio_servicio?
  end

  test "sin el PIN correcto no pasa nada" do
    error = assert_raises(QuitarCambioServicio::PinInvalido) { quitar(pin: "9999").call }

    assert_match(/PIN/, error.message)
    assert @paquete.reload.solicito_cambio_servicio?, "apagó el cobro con un PIN equivocado"
  end

  test "un rol que no esta en la lista no puede" do
    # `supervisor_miami` y `admin`, nadie más. Agregar este flujo a
    # `ROLES_AUTORIZANTES` le habría dado a Miami autorización sobre CUALQUIER
    # línea de pre-factura — mucho más de lo que pidió.
    cajero = users(:cajero)
    cajero.update!(pin: "1234")

    assert_raises(QuitarCambioServicio::NoPermitido) { quitar(supervisor: cajero).call }
    assert @paquete.reload.solicito_cambio_servicio?
  end

  test "un supervisor sin PIN asignado tampoco" do
    @supervisor.update_columns(pin_digest: nil)

    assert_raises(QuitarCambioServicio::NoPermitido) { quitar.call }
  end

  test "un supervisor inactivo tampoco" do
    @supervisor.update!(activo: false)

    assert_raises(QuitarCambioServicio::NoPermitido) { quitar.call }
  end

  test "el supervisor_miami si puede" do
    # Es el rol de Julien, que es a quien el digitador le va a pedir el favor.
    julien = users(:digitador).dup
    julien.assign_attributes(email_address: "julien@cec.test", rol: "supervisor_miami",
                             password: "password123", pin: "4321")
    julien.save!

    assert quitar(supervisor: julien, pin: "4321").call
    assert_not @paquete.reload.solicito_cambio_servicio?
  end

  test "se lleva la linea automatica de la pre-factura" do
    linea = crear_linea_de_cobro

    quitar.call

    assert_not PreFacturaItem.exists?(linea.id), "quedó la línea cobrando"
  end

  test "no toca una linea que el cajero escribio a mano" do
    manual = crear_linea_de_cobro(origen: "manual")

    quitar.call

    assert PreFacturaItem.exists?(manual.id),
           "borró una línea manual: este flujo solo saca la automática"
  end

  test "un paquete ya facturado se rechaza" do
    # Sacar un cobro que ya salió en un documento fiscal es una nota de
    # crédito, no un flag.
    pf = crear_pre_factura
    pf.update_columns(estado: "facturado")

    error = assert_raises(QuitarCambioServicio::YaFacturado) { quitar.call }

    assert_match(/nota de cr/i, error.message)
    assert @paquete.reload.solicito_cambio_servicio?
  end

  test "queda registrado en el audit log" do
    assert_difference -> { PaperTrail::Version.where(item_type: "Paquete", item_id: @paquete.id).count }, 1 do
      quitar.call
    end
  end

  private

  def quitar(paquete: @paquete, supervisor: @supervisor, pin: "1234")
    QuitarCambioServicio.new(paquete: paquete, supervisor: supervisor, pin: pin, motivo: "error de ingreso")
  end

  def crear_pre_factura
    pf = PreFactura.create!(cliente: @paquete.cliente, moneda: "LPS", creado_por: @supervisor)
    @paquete.update_columns(pre_factura_id: pf.id)
    pf
  end

  def crear_linea_de_cobro(origen: "auto_servicio_extra")
    pf = @paquete.pre_factura || crear_pre_factura
    servicio = ServicioExtra.find_or_create_by!(codigo: "CAMBIO_SERVICIO") do |s|
      s.descripcion = "Cambio de servicio"
      s.precio_venta = 100
      s.moneda = "LPS"
    end
    pf.pre_factura_items.create!(
      paquete: @paquete, servicio_extra: servicio, concepto: "Cambio de servicio",
      subtotal: 86.96, origen: origen
    )
  end
end
