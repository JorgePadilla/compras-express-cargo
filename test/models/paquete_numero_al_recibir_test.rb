require "test_helper"

# C18-04: el número de recepción se genera también cuando un paquete ya
# persistido se recibe —el esperado de una pre-alerta que entra con una sola
# etiqueta, o el que pasa por actualizar—, y solo entonces.
class PaqueteNumeroAlRecibirTest < ActiveSupport::TestCase
  setup do
    @cliente = clientes(:juan)
    @miami = sucursales(:miami)
  end

  def esperado(tracking)
    Paquete.create!(cliente: @cliente, tipo_envio: tipo_envios(:cer), tracking: tracking,
                    descripcion: "Anunciado", estado: "pre_alerta_estado", user: users(:digitador))
  end

  test "un esperado que se recibe toma numero y WR aunque sea un update" do
    p = esperado("1ZNUMERO00000001")
    assert_nil p.numero_recepcion

    p.update!(estado: "recibido_miami", sucursal_recepcion: @miami)

    assert p.numero_recepcion.present?
    assert p.numero_recepcion.start_with?("R#{@miami.codigo}")
    assert p.warehouse_receipt.present?
  end

  test "un esperado editado con la sucursal de retiro NO se numera" do
    # `sucursal` es dónde retira el cliente; el número es de dónde se recibió.
    p = esperado("1ZNUMERO00000002")

    p.update!(sucursal: Sucursal.find_by!(ubicacion: "honduras"))

    assert_nil p.numero_recepcion, "un paquete que no llegó no tiene número de recepción"
  end

  test "un esperado con sucursal de recepcion pero todavia esperado tampoco" do
    p = esperado("1ZNUMERO00000003")

    p.update!(sucursal_recepcion: @miami)

    assert_nil p.numero_recepcion
  end

  test "una fila vieja con el tracking de numero no acuña un WR al editarse" do
    p = Paquete.create!(cliente: @cliente, tipo_envio: tipo_envios(:cer), tracking: "1ZVIEJO000000004",
                        descripcion: "Legacy", estado: "recibido_miami", user: users(:digitador))
    p.update_columns(numero_recepcion: "1ZVIEJO000000004", warehouse_receipt_id: nil)

    p.update!(descripcion: "Legacy corregido")

    assert_nil p.reload.warehouse_receipt_id, "un after_save ancho acuñaría un WR con un tracking de courier"
  end

  test "numerar_recibidos_sin_numero! numera los recibidos, informa los sin sucursal y salta los esperados" do
    recibido = Paquete.create!(cliente: @cliente, tipo_envio: tipo_envios(:cer), tracking: "1ZBACKFILL000001",
                               descripcion: "Recibido", estado: "recibido_miami", user: users(:digitador),
                               sucursal_recepcion: @miami)
    recibido.update_columns(numero_recepcion: nil, warehouse_receipt_id: nil)
    sin_sucursal = Paquete.create!(cliente: @cliente, tipo_envio: tipo_envios(:cer), tracking: "1ZBACKFILL000002",
                                   descripcion: "Recibido", estado: "recibido_miami", user: users(:digitador))
    sin_sucursal.update_columns(numero_recepcion: nil, warehouse_receipt_id: nil)
    esperado = esperado("1ZBACKFILL000003")
    esperado.update_columns(sucursal_recepcion_id: @miami.id)

    resultado = Paquete.numerar_recibidos_sin_numero!

    assert_equal [ recibido.id ], resultado[:numerados].map(&:first)
    assert recibido.reload.numero_recepcion.present?
    assert recibido.warehouse_receipt.present?
    assert_includes resultado[:sin_sucursal], [ sin_sucursal.id, sin_sucursal.tracking ]
    assert_nil esperado.reload.numero_recepcion
    assert_empty Paquete.numerar_recibidos_sin_numero![:numerados], "no es idempotente"
  end

  test "una fila que ya no pasa las validaciones de hoy igual se numera" do
    p = Paquete.create!(cliente: @cliente, tipo_envio: tipo_envios(:cer), tracking: "1ZBACKFILL000004",
                        descripcion: "Recibido", estado: "recibido_miami", user: users(:digitador),
                        sucursal_recepcion: @miami)
    p.update_columns(numero_recepcion: nil, warehouse_receipt_id: nil, descripcion: nil)

    resultado = Paquete.numerar_recibidos_sin_numero!

    assert_includes resultado[:numerados].map(&:first), p.id
    assert p.reload.numero_recepcion.present?
    assert p.warehouse_receipt.present?
  end
end
