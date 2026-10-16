require "test_helper"

# RP-87 · El manifiesto cuya carga ya se pre-facturó entera dice «Terminado de
# Prefacturar». Yusef, 2026-10-11: *"deberíamos ponerlos con el estatus de
# Terminado de Prefacturar"*; y el 2026-10-12, en la hoja: *"el montón de guías
# que ya no deberían de aparecer, porque ya se terminaron"* (`C31-15`).
class ManifiestoTerminadoDePrefacturarTest < ActiveSupport::TestCase
  setup do
    @manifiesto = manifiestos(:creado)
    @manifiesto.update_columns(estado: "recibido")
    @uno = paquete
    @dos = paquete
  end

  def paquete
    Paquete.create!(tracking: "1ZTERMINADO#{SecureRandom.hex(3).upcase}", cliente: clientes(:juan),
                    estado: "en_aduana", manifiesto: @manifiesto, tipo_envio: tipo_envios(:cer))
  end

  def pre_facturar(*paquetes)
    paquetes.each { |p| p.update_columns(pre_factura_id: pre_facturas(:borrador_juan).id) }
  end

  def releido = Manifiesto.find(@manifiesto.id)

  test "con un paquete esperando su pre-factura no está terminado" do
    pre_facturar(@uno)

    assert_not releido.terminado_de_prefacturar?
    assert_equal "Recibido", releido.estado_texto
  end

  test "con todo pre-facturado dice «Terminado de Prefacturar»" do
    pre_facturar(@uno, @dos)

    assert releido.terminado_de_prefacturar?
    assert_equal "Terminado de Prefacturar", releido.estado_texto
  end

  # Se deriva, no se sella: si una pre-factura se anula, el paquete vuelve a
  # esperar y el manifiesto vuelve a la hoja, sin nada que desmarcar.
  test "si un paquete vuelve a quedar sin pre-factura, deja de estar terminado" do
    pre_facturar(@uno, @dos)
    @dos.update_columns(pre_factura_id: nil)

    assert_not releido.terminado_de_prefacturar?
  end

  test "sin nada pre-facturado, o todavía en camino, no está terminado" do
    assert_not releido.terminado_de_prefacturar?

    pre_facturar(@uno, @dos)
    @manifiesto.update_columns(estado: "enviado")
    assert_not releido.terminado_de_prefacturar?, "en camino no se pre-factura"
  end

  test "la lista anota a todos con una sola pasada" do
    pre_facturar(@uno, @dos)
    otro = manifiestos(:enviado)

    lista = Manifiesto.precargar_terminados(Manifiesto.where(id: [ @manifiesto.id, otro.id ]).load)

    assert lista.find { |m| m.id == @manifiesto.id }.terminado_de_prefacturar?
    assert_not lista.find { |m| m.id == otro.id }.terminado_de_prefacturar?
  end
  # C32-01 · El historial filtra con la consulta, la vista pinta con el
  # método: tienen que decir lo mismo en cada caso, o el filtro «Terminado»
  # traería manifiestos que la fila no llama así.
  test "la consulta y el método dicen lo mismo" do
    casos = {
      "con uno esperando" => -> { pre_facturar(@uno) },
      "todo pre-facturado" => -> { pre_facturar(@uno, @dos) },
      "todo, pero en camino" => -> { pre_facturar(@uno, @dos); @manifiesto.update_columns(estado: "enviado") }
    }
    casos.each do |nombre, preparar|
      Paquete.where(manifiesto_id: @manifiesto.id).update_all(pre_factura_id: nil)
      @manifiesto.update_columns(estado: "recibido")
      preparar.call

      assert_equal Manifiesto.terminados_de_prefacturar_entre([ releido ]).include?(@manifiesto.id),
                   Manifiesto.terminados_de_prefacturar.exists?(@manifiesto.id), nombre
    end
  end
end
