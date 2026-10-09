require "test_helper"

# C25-08 · El preview de `/ajustes_etiqueta` no puede mentir sobre la sucursal.
#
# La muestra tenía «San Pedro Sula» **escrito a mano**, y ésa es una ciudad, no
# una sucursal: Yusef la vio y mandó que dijera «Zerón SPS» — *"así se llama la
# sucursal"*. Lo que se ve en el editor tiene que ser lo que sale impreso, y lo
# que sale impreso desde `C25-08` es la sucursal de retiro por defecto.
class EtiquetaPlantillaMuestraTest < ActiveSupport::TestCase
  test "la muestra usa la sucursal de retiro por defecto de verdad" do
    Sucursal.update_all(retiro_por_defecto: false)
    sucursales(:zeron_sps).update!(retiro_por_defecto: true)

    assert_equal sucursales(:zeron_sps).nombre, EtiquetaPlantilla.paquete_de_muestra.sucursal.nombre
  end

  test "sin sucursal por defecto la muestra igual dice una sucursal, no una ciudad" do
    Sucursal.update_all(retiro_por_defecto: false)

    nombre = EtiquetaPlantilla.paquete_de_muestra.sucursal.nombre
    assert_match(/SPS/, nombre)
    assert_no_match(/San Pedro Sula/, nombre, "la ciudad escrita a mano era el bug")
  end
end
