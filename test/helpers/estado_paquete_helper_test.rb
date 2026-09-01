require "test_helper"

# A7-12 / A7-13 / A7-14 / A7-15 — cómo se lee el estado de un paquete.
class EstadoPaqueteHelperTest < ActionView::TestCase
  include EstadoPaqueteHelper

  setup do
    @tgu = sucursales(:humuya_tgu)
    @cliente = clientes(:juan)
  end

  test "el dropdown va en orden de proceso, no en orden de enum" do
    orden = Paquete::ESTADOS_SELECCIONABLES
    assert_operator orden.index("recibido_miami"), :<, orden.index("en_aduana")
    assert_operator orden.index("en_aduana"), :<, orden.index("disponible_entrega")
    assert_operator orden.index("disponible_entrega"), :<, orden.index("entregado")
    assert_operator orden.index("entregado"), :<, orden.index("anulado"),
                    "los desvíos van al final, después del camino normal"
  end

  # A7-11. Yusef: "el prefacturado no es un estado, ese tenés que eliminar".
  # Este test decía lo contrario —que tenía que seguir en el enum porque lo
  # escribía PreFactura#confirmar!—, y era cierto hasta que confirmar! pasó a
  # escribir `disponible_entrega`. Se da vuelta: ahora traba que vuelva.
  test "pre_facturado no existe, ni para elegir ni en el enum" do
    refute_includes Paquete::ESTADOS_SELECCIONABLES, "pre_facturado"
    refute_includes Paquete.estados.keys, "pre_facturado",
                    "volvió al enum: Yusef lo mandó eliminar (A7-11)"
    refute_includes Paquete::ESTADOS_ORDEN, "pre_facturado"
  end

  # El rótulo se queda aunque el estado no exista: paper_trail guarda versiones
  # viejas que lo nombran y la bitácora las muestra.
  test "el rótulo legacy sobrevive para la bitácora" do
    assert_equal "Pre-facturado", estado_etiqueta("pre_facturado")
  end

  test "todo lo seleccionable existe en el enum" do
    inventados = Paquete::ESTADOS_SELECCIONABLES - Paquete.estados.keys
    assert_empty inventados, "estados en el dropdown que el modelo no conoce"
  end

  # A7-14. "No, enviado. Porque 'en camino' van a creer que ya va para ahí
  # ahorita."
  test "el rotulo dice enviado, nunca en camino" do
    assert_equal "Enviado a sucursal", estado_etiqueta("enviado_sucursal")
    refute_match(/camino/i, Paquete::ESTADOS_SELECCIONABLES.map { |e| estado_etiqueta(e) }.join(" "))
  end

  # A7-13. El cliente llamaba preguntando dónde estaba el paquete.
  test "disponible dice en que sucursal" do
    p = paquete(estado: "disponible_entrega", sucursal: @tgu)
    assert_equal "Disponible en sucursal #{@tgu.nombre}", estado_de(p)
  end

  test "sin sucursal no se inventa uno" do
    p = paquete(estado: "disponible_entrega", sucursal: nil)
    assert_equal "Disponible", estado_de(p),
                 "decir una sucursal equivocada es peor que no decir ninguna"
  end

  test "enviado a sucursal usa el destino, no el de retiro" do
    p = paquete(estado: "enviado_sucursal", sucursal: sucursales(:miami))
    p.sucursal_destino = @tgu
    assert_equal "Enviado a sucursal #{@tgu.nombre}", estado_de(p)
  end

  # A7-09. El estado sirve para auditar el paquete que se quedó sin enviar, y
  # sin destino no audita nada. Pero exigirlo a secas rompería el dropdown de
  # /paquetes, así que primero se hereda el de retiro — que es el caso normal.
  test "enviado a sucursal hereda el destino del de retiro" do
    p = Paquete.create!(tracking: "DEST#{SecureRandom.hex(3)}", cliente: @cliente,
                        sucursal: @tgu, estado: "recibido_miami")
    p.update!(estado: "enviado_sucursal")

    assert_equal @tgu, p.reload.sucursal_destino
  end

  test "sin sucursal de retiro ni destino, no se puede marcar enviado a sucursal" do
    p = Paquete.create!(tracking: "DEST#{SecureRandom.hex(3)}", cliente: @cliente,
                        sucursal: nil, estado: "recibido_miami")

    refute p.update(estado: "enviado_sucursal")
    assert_includes p.errors.attribute_names, :sucursal_destino
  end

  # A7-15. "Las iniciales de la sucursal donde se entregó, para que uno pueda
  # entender en dónde se entregó."
  test "entregado lleva las iniciales de la sucursal" do
    p = paquete(estado: "entregado", sucursal: @tgu)
    assert_equal "Entregado (#{@tgu.codigo})", estado_de(p)
  end

  private

  def paquete(estado:, sucursal:)
    Paquete.new(tracking: "EST#{SecureRandom.hex(3)}", cliente: @cliente,
                estado: estado, sucursal: sucursal)
  end
end
