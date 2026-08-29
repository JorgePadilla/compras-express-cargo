require "test_helper"

# C19-06: el value object de la plantilla de la etiqueta. La regla madre,
# calcada de EtiquetaAjustes: un valor basura cae al default, nunca a la
# impresora — y basura en una clave no tumba el resto.
class EtiquetaPlantillaDefinicionTest < ActiveSupport::TestCase
  DEF = EtiquetaPlantilla::Definicion

  test "la de fábrica es la etiqueta de hoy, valor por valor" do
    d = DEF.new(nil)

    assert_equal 2.25, d.ancho_in
    assert_equal 1.25, d.alto_in
    assert_equal 100, d.escala_pct

    # Los tiers --t1..--t7 históricos, campo por campo.
    assert_equal 19.0, d.pt("tipo_envio"), "t1: lo más grande de la etiqueta"
    assert_equal 11.0, d.pt("numero_recepcion")
    assert_equal 10.5, d.pt("cliente_codigo")
    assert_equal 10.5, d.pt("fraccion")
    assert_equal 9.5,  d.pt("cliente_nombre")
    assert_equal 9.5,  d.pt("sucursal")
    assert_equal 7.0,  d.pt("tracking")
    assert_equal 7.0,  d.pt("tracking_secundario")
    assert_equal 6.5,  d.pt("fecha")
    assert_equal 6.5,  d.pt("reg")
    assert_equal 6.5,  d.pt("proveedor")
    assert_equal 6.0,  d.pt("tercero")
    assert_equal 6.0,  d.pt("driver")
    assert_equal 6.0,  d.pt("ubicacion")
    assert_equal 6.0,  d.pt_rotulo("reg")
    assert_equal 6.0,  d.pt_rotulo("sucursal")

    assert_equal "RETIRA EN", d.texto("sucursal")
    assert_equal "Reg:", d.texto("reg")
    assert_equal "Drv:", d.texto("driver")
    assert_equal "3ro:", d.texto("tercero")

    # Todos los campos, visibles y repartidos en las filas de fábrica.
    DEF::CAMPOS.each_key { |c| assert d.visible?(c), "#{c} arranca visible" }
    assert_equal DEF::CAMPOS.keys.sort,
                 d.filas.flat_map { |f|
                   f["tipo"] == "dos_columnas" ? (f["izquierda"] + f["derecha"]).flatten : f["campos"]
                 }.sort
  end

  test "cada clamp cae al default de su clave sin tumbar el resto" do
    d = DEF.new(DEF::DEFAULT.deep_merge(
      "escala_pct" => 400,
      "dim" => { "ancho_in" => 12, "alto_in" => 0.1 },
      "campos" => {
        "tipo_envio" => { "pt" => 99 },
        "sucursal"   => { "texto" => "x" * 40 },
        "tercero"    => { "pt" => 8.0 }
      }
    ))

    assert_equal 100, d.escala_pct
    assert_equal 2.25, d.ancho_in
    assert_equal 1.25, d.alto_in
    assert_equal 19.0, d.pt("tipo_envio"), "99pt no entra en una Dymo"
    assert_equal "RETIRA EN", d.texto("sucursal"), "40 chars no caben"
    assert_equal 8.0, d.pt("tercero"), "el valor válido de al lado sí rige"
  end

  test "la escala multiplica y fs redondea" do
    d = DEF.new(DEF::DEFAULT.deep_merge("escala_pct" => 110))

    assert_equal 20.9, d.fs("tipo_envio")
    assert_equal 6.6, d.fs_rotulo("sucursal")
  end

  test "la identidad no se apaga ni pidiéndolo" do
    d = DEF.new(DEF::DEFAULT.deep_merge("campos" => {
      "tracking" => { "visible" => false },
      "barcode" => { "visible" => false },
      "tipo_envio" => { "visible" => false },
      "numero_recepcion" => { "visible" => false },
      "tercero" => { "visible" => false }
    }))

    assert d.visible?("tracking"), "el tracking se compara contra la caja"
    assert d.visible?("barcode"), "sin barcode no se escanea en San Pedro"
    assert d.visible?("tipo_envio"), "es la bandera (RET incluido)"
    assert d.visible?("numero_recepcion")
    assert_not d.visible?("tercero"), "los opcionales sí se apagan"
  end

  test "filas rotas caen a las de fábrica enteras" do
    [ "basura", [ { "campos" => "no-array" } ], [ { "tipo" => "dos_columnas" } ] ].each do |filas|
      d = DEF.new(DEF::DEFAULT.merge("filas" => filas))
      assert_equal DEF::DEFAULT["filas"], d.filas,
                   "no cayó al default con filas=#{filas.inspect[0, 60]}"
    end
  end

  # C20-08: lo que falta o sobra se reconcilia. Antes se exigía cobertura
  # exacta, y eso convertía cada campo nuevo del sistema en un reseteo
  # silencioso del orden que el operario había armado.
  test "un campo que falta vuelve, sin tirar el orden que el operario armó" do
    sin_tracking = DEF::DEFAULT["filas"].reject { |f| f["id"] == "f-tracking" }
    d = DEF.new(DEF::DEFAULT.merge("filas" => sin_tracking))

    campos = campos_de(d.filas)
    assert_equal DEF::CAMPOS.keys.sort, campos.sort, "se perdió un campo"
    # Y el orden propio se respeta: el barcode sigue primero.
    assert_equal "barcode", campos.first
  end

  test "un campo repetido o desconocido se descarta, y el resto queda" do
    con_basura = DEF::DEFAULT["filas"] + [ { "id" => "x", "campos" => [ "tracking", "inventado" ] } ]
    d = DEF.new(DEF::DEFAULT.merge("filas" => con_basura))

    campos = campos_de(d.filas)
    assert_equal DEF::CAMPOS.keys.sort, campos.sort
    assert_equal campos.uniq, campos, "quedó un campo repetido"
  end

  def campos_de(filas)
    filas.flat_map do |f|
      f["tipo"] == "dos_columnas" ? (f["izquierda"] + f["derecha"]).flatten : f["campos"]
    end
  end

  test "otra version o un no-hash rinden el default entero" do
    assert_equal 19.0, DEF.new("garbage").pt("tipo_envio")
    assert_equal 2.25, DEF.new(DEF::DEFAULT.merge("version" => 2, "dim" => { "ancho_in" => 3.0 })).ancho_in
  end

  test "vigente jamás revienta" do
    EtiquetaPlantilla.create!(definicion: { "version" => 1, "campos" => "basura", "dim" => [ 1 ] })

    d = EtiquetaPlantilla.vigente
    assert_equal 19.0, d.pt("tipo_envio")
    assert_equal 2.25, d.ancho_in
  end
end
