require "test_helper"

# PR-C6.14b: teclear los últimos dígitos del código y que caiga el correcto.
#
# Yusef, 2026-08-08, mostrando cómo trabajan hoy:
#
#   "El rollo de los códigos de cliente actuales es que tienen el C00002867...
#    el sistema lee de derecha a izquierda."
#   "Solo le ponían el dos, ponele que el mío es el seis, solo poníamos el seis
#    o el dos y ya con eso cae."
#
# **Encontrar ya funcionaba**: `codigo ILIKE '%2867%'` matchea el sufijo y los
# ceros a la izquierda ya se ignoraban (PR-10.f). Lo que faltaba era el
# **orden** — con códigos de 5 dígitos, teclear `6` trae decenas y el que uno
# quiere queda enterrado. Esa era la pregunta abierta del Excel.
class ClienteBusquedaSufijoTest < ActiveSupport::TestCase
  setup do
    @exacto   = crear("C00002867", "Yusef")
    @termina  = crear("C00012867", "Otro")
    @contiene = crear("C00028670", "Tercero")
  end

  test "el codigo que ES ese numero va primero" do
    resultado = Cliente.activos.buscar_flexible("2867").to_a

    assert_equal @exacto, resultado.first,
                 "el que uno busca quedó enterrado entre los que contienen el número"
  end

  test "despues va el que TERMINA en ese numero" do
    resultado = Cliente.activos.buscar_flexible("2867").to_a

    assert_operator resultado.index(@termina), :<, resultado.index(@contiene)
  end

  test "los ceros a la izquierda se siguen ignorando" do
    # Comportamiento de PR-10.f que no se puede romper: C002 == C2 == 2.
    seis = crear("C00006", "Seis")

    assert_includes Cliente.activos.buscar_flexible("6").to_a, seis
    assert_equal seis, Cliente.activos.buscar_flexible("6").first
  end

  test "buscar por nombre sigue funcionando" do
    # El desempate solo aplica cuando el término trae dígitos. Sin ellos, la
    # búsqueda queda exactamente como estaba.
    assert_includes Cliente.activos.buscar_flexible("Yusef").to_a, @exacto
  end

  test "un termino mixto no rompe el orden" do
    # "2867 Samara" — la etiqueta rota que Yusef describió en su momento.
    resultado = Cliente.activos.buscar_flexible("2867 Yusef").to_a

    assert_equal @exacto, resultado.first
  end

  test "el codigo completo tambien cae en el correcto" do
    assert_equal @exacto, Cliente.activos.buscar_flexible("C00002867").first
  end

  private

  def crear(codigo, nombre)
    Cliente.create!(codigo: codigo, nombre: nombre, apellido: "Prueba", activo: true)
  end
end
