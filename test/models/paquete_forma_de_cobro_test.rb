require "test_helper"

# PR-C6.39: el origen del paquete decide **cuál** de las tres formas de cobro
# aplica.
#
# Yusef, contestando la pregunta 19 —escrito a mano al lado de "Cambia el precio
# o el proceso"—:
#
#   "Se utiliza para **el cobro** en Entrega Personal o en PreFactura."
#
# `PR-C6.38` lo había resuelto derivándolo de la sucursal de recepción y lo
# documentó como **informativo**. La derivación estaba bien —el audio la
# confirma: "si es en Miami, donde están recibiendo… si es fuera de ahí, ahí es
# donde está eso"— pero la conclusión no.
#
# Encaja con lo que ya está en pantalla: el panel de cálculo muestra **tres
# formas** (USA→HN por libra o volumen, USA→HN por pie³, China→HN por m³) y hoy
# las tres se pintan igual, con dos rotuladas "no afluye en precio".
#
# **Lo que este test NO afirma:** cuánto se cobra. El papel dice *dónde* se usa
# el origen, no *cómo* multiplica. Marcar cuál forma aplica es lo que está
# autorizado; convertirlo en un multiplicador sin que él lo confirme sería
# inventar una regla de plata.
class PaqueteFormaDeCobroTest < ActiveSupport::TestCase
  setup do
    @paquete = paquetes(:recibido)
  end

  test "lo recibido en Miami se cobra por libra o volumen" do
    @paquete.update!(sucursal_recepcion: sucursales(:miami))

    assert_equal :libra_o_volumen, @paquete.forma_de_cobro
    assert_not @paquete.cobra_por_metro_cubico?
  end

  test "lo recibido en China se cobra por metro cubico" do
    china = Sucursal.create!(codigo: "PVG", nombre: "Shanghai", pais: "China",
                             ubicacion: "otros", codigo_recepcion_prefix: "RSH")
    @paquete.update!(sucursal_recepcion: china)

    assert_equal :metros_cubicos, @paquete.forma_de_cobro
    assert @paquete.cobra_por_metro_cubico?
  end

  test "un origen que no conocemos cae a la forma de siempre" do
    # Si mañana abren Panamá y nadie define su regla, se cobra como siempre —
    # no se inventa una forma nueva ni se rompe el cobro.
    panama = Sucursal.create!(codigo: "PTY", nombre: "Panama City", pais: "Panamá",
                              ubicacion: "otros", codigo_recepcion_prefix: "RPA")
    @paquete.update!(sucursal_recepcion: panama)

    assert_equal :libra_o_volumen, @paquete.forma_de_cobro
  end

  test "sin origen tampoco se rompe" do
    @paquete.update_columns(sucursal_recepcion_id: nil, sucursal_id: nil)

    assert_equal :libra_o_volumen, @paquete.reload.forma_de_cobro
  end

  test "el peso a cobrar NO cambia por el origen" do
    # La garantía de este PR: marca cuál forma aplica, no mueve ningún monto.
    # Si esto falla, el PR se pasó de lo que el papel autoriza.
    china = Sucursal.create!(codigo: "CAN", nombre: "Guangzhou", pais: "China",
                             ubicacion: "otros", codigo_recepcion_prefix: "RGZ")

    # Se guarda primero con la sucursal de siempre para que el callback que
    # recalcula `peso_cobrar` ya haya corrido: si no, el test mediría ese
    # recálculo en vez de medir el origen.
    @paquete.update!(sucursal_recepcion: sucursales(:miami))
    antes = @paquete.reload.peso_cobrar

    @paquete.update!(sucursal_recepcion: china)

    assert_equal antes, @paquete.reload.peso_cobrar,
                 "el origen movió el peso a cobrar: este PR solo debe marcar qué forma aplica"
  end
end
