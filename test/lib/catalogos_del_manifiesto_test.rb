require "test_helper"
require Rails.root.join("lib/catalogos_del_manifiesto")

# C21-08 · La semilla de los catálogos del manifiesto.
#
# Existe porque el deploy de staging **solo migra, no siembra**, así que un
# catálogo nuevo nace vacío allá. `PR-M1` estrenó tres y en staging siguieron en
# blanco hasta que Jorge lo vio: *"nos faltaron los seeds de los catálogos, solo
# empresas proveedoras tenemos"*.
class CatalogosDelManifiestoTest < ActiveSupport::TestCase
  # Las fixtures cargan filas de estos catálogos, así que para probar la
  # siembra hay que partir de vacío de verdad.
  def vaciar
    Manifiesto.update_all(tipo_envio_proveedor_id: nil, consignatario_id: nil, empresa_manifiesto_id: nil)
    CajaManifiesto.update_all(tamano_caja_id: nil)
    [ TipoEnvioProveedor, Consignatario, TamanoCaja, EmpresaManifiesto ].each(&:delete_all)
  end

  test "sobre una base vacía crea los cuatro catálogos" do
    vaciar

    CatalogosDelManifiesto.sembrar!

    assert_equal 3, EmpresaManifiesto.count
    assert_equal 2, TipoEnvioProveedor.count
    assert_equal 1, Consignatario.count
    assert_equal 10, TamanoCaja.count, "los diez tamaños de la pantalla vieja"
  end

  # Corre en cada deploy: tiene que poder correrse mil veces.
  test "es idempotente" do
    vaciar
    CatalogosDelManifiesto.sembrar!

    assert_no_difference [ "EmpresaManifiesto.count", "TipoEnvioProveedor.count",
                           "Consignatario.count", "TamanoCaja.count" ] do
      3.times { CatalogosDelManifiesto.sembrar! }
    end
  end

  # No pisa lo que el equipo cargó por el CRUD — que es la mitad del pedido de
  # Yusef: *"entre más cosas nos dejes crear, menos te molestaremos"*.
  test "no toca lo que ya estaba" do
    vaciar
    propio = TipoEnvioProveedor.create!(nombre: "CARGA CONSOLIDADA", activo: false)

    CatalogosDelManifiesto.sembrar!

    assert_equal "CARGA CONSOLIDADA", propio.reload.nombre
    assert_not propio.activo?, "ni siquiera le cambia el activo"
  end

  # Los diez nombres son los de la pantalla vieja (`C21-04`), en su orden.
  test "los tamaños son los diez del legacy, ordenados" do
    vaciar
    CatalogosDelManifiesto.sembrar!

    assert_equal [ "Especificar", "EH", "D", "22 Cubo", "18 Cubo",
                   "D G", "EH G", "E", "Mini D", "Mini D Doble" ],
                 TamanoCaja.ordered.pluck(:nombre)
  end

  # `Mini D` es el único con medidas: la pantalla vieja muestra 595.78 de volumen
  # para 46×43×50, que es exactamente lo que da el divisor 166. Las otras nueve
  # las mide Miami.
  test "solo Mini D trae medidas, y son las que dan el volumen del legacy" do
    vaciar
    CatalogosDelManifiesto.sembrar!

    mini = TamanoCaja.find_by(nombre: "Mini D")
    assert_equal [ 46, 43, 50 ], [ mini.alto, mini.largo, mini.ancho ].map(&:to_i)
    # Es la misma cuenta que hace `CajaManifiesto#volumen_calculado`.
    volumen = (VolumetricoCalculator.pulgadas_cubicas(46, 43, 50) /
               VolumetricoCalculator::DIVISOR_LB).round(2)
    assert_in_delta 595.78, volumen, 0.01

    con_medidas = TamanoCaja.where.not(alto: nil).pluck(:nombre)
    assert_equal [ "Mini D" ], con_medidas
  end

  # «Especificar» es la opción para la caja que no entra en ningún tamaño.
  test "Especificar va sin medidas a propósito" do
    vaciar
    CatalogosDelManifiesto.sembrar!

    assert_not TamanoCaja.find_by(nombre: "Especificar").medidas_completas?
  end
end
