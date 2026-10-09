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

  # **Ya no es solo Mini D.** Hasta el 2026-09-05 era el único con medidas —la
  # única derivable, del 595.78 que muestra la pantalla vieja— y las otras nueve
  # iban en nil. Ese día salieron del propio sistema viejo, del viewmodel
  # `TamanoCajasPredefinidoVM` que su editor de manifiestos publica en la
  # página, con Jorge mirando. Mini D coincidió **exacta** con la derivada, que
  # es la mejor señal de que la derivación era buena.
  test "los nueve tamaños de verdad traen sus medidas" do
    vaciar
    CatalogosDelManifiesto.sembrar!

    sin_medidas = TamanoCaja.where(alto: nil).pluck(:nombre)
    assert_equal [ "Especificar" ], sin_medidas,
                 "solo «Especificar» va sin medidas; las demás salieron del sistema viejo"

    mini = TamanoCaja.find_by(nombre: "Mini D")
    assert_equal [ 46, 43, 50 ], [ mini.alto, mini.largo, mini.ancho ].map(&:to_i)
  end

  # El número que la pantalla vieja llama «Dimensión» es **nuestro volumen**:
  # alto × largo × ancho ÷ 166. Verificado contra la pantalla el 2026-09-05, y
  # es lo que ata este catálogo al `VolumetricoCalculator` — por eso la
  # Dimensión no se guarda: se deriva.
  test "la «Dimensión» de la pantalla vieja es nuestro volumen" do
    vaciar
    CatalogosDelManifiesto.sembrar!

    { "Mini D" => 595.78, "EH" => 114.72 }.each do |nombre, dimension|
      t = TamanoCaja.find_by(nombre: nombre)
      calculado = (VolumetricoCalculator.pulgadas_cubicas(t.alto, t.largo, t.ancho) /
                   VolumetricoCalculator::DIVISOR_LB).round(2)

      assert_in_delta dimension, calculado, 0.01,
                      "#{nombre} tendría que dar #{dimension}, como la pantalla vieja"
    end
  end

  # ── El relleno de los que ya existían ────────────────────────────────────
  #
  # Los diez se sembraron el 2026-08-31 **sin medidas**. `find_or_create_by!`
  # solo corre su bloque al **crear**, así que sin este relleno los ocho que ya
  # están en staging se quedarían vacíos para siempre y el dato que se sacó del
  # sistema viejo no llegaría a nadie.

  test "le pone las medidas al tamaño que ya existía sin ellas" do
    vaciar
    TamanoCaja.create!(nombre: "EH", position: 2, activo: true)

    CatalogosDelManifiesto.sembrar!

    eh = TamanoCaja.find_by(nombre: "EH")
    assert_equal [ 23, 36, 23 ], [ eh.alto, eh.largo, eh.ancho ].map(&:to_i)
  end

  # **Y no le pisa la medida a quien la midió.** Si Miami corrigió el catálogo
  # con la cinta en la mano, ese dato vale más que el del sistema que estamos
  # reemplazando — y esto corre en **cada deploy**, así que sin la guarda se la
  # revertiría una y otra vez.
  test "no le pisa una medida que alguien ya corrigió" do
    vaciar
    TamanoCaja.create!(nombre: "EH", position: 2, activo: true, alto: 99, largo: 88, ancho: 77)

    CatalogosDelManifiesto.sembrar!

    eh = TamanoCaja.find_by(nombre: "EH")
    assert_equal [ 99, 88, 77 ], [ eh.alto, eh.largo, eh.ancho ].map(&:to_i)
  end

  # Y rellena **por medida**, no por tamaño: si alguien puso solo el alto, las
  # otras dos entran igual.
  test "rellena solo las medidas que faltan" do
    vaciar
    TamanoCaja.create!(nombre: "EH", position: 2, activo: true, alto: 99)

    CatalogosDelManifiesto.sembrar!

    eh = TamanoCaja.find_by(nombre: "EH")
    assert_equal [ 99, 36, 23 ], [ eh.alto, eh.largo, eh.ancho ].map(&:to_i)
  end

  # «Especificar» es la opción para la caja que no entra en ningún tamaño.
  test "Especificar va sin medidas a propósito" do
    vaciar
    CatalogosDelManifiesto.sembrar!

    assert_not TamanoCaja.find_by(nombre: "Especificar").medidas_completas?
  end
end
