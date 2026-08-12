require "test_helper"
require "prawn"
require "prawn/table"
require Rails.root.join("lib/servicios_pdf")

# PR: el PDF de los servicios que se le manda a Yusef para revisar.
#
# Los tres PDF que ya se le mandaban —resumen, historia, preguntas— **no tenían
# ninguna prueba**: su contenido y sus helpers vivían adentro de `docs.rake`, y
# Minitest no carga los `.rake`. Un `Prawn::Errors::CannotFit` por anchos de
# tabla mal repartidos solo se descubría corriendo la tarea, a mano.
#
# Por eso este documento vive en una clase y los datos salen de métodos puros:
# lo que se puede probar de verdad es de dónde salen los números, y el render
# queda como prueba de humo.
class ServiciosPdfTest < ActiveSupport::TestCase
  # Las tarifas se siembran acá y no en un fixture global a propósito: hoy el
  # test DB no tiene ninguna, y varios tests de pre-factura y del cotizador
  # dependen de eso — ejercitan el camino "sin tarifa, cae al precio del tipo de
  # envío". Un `tarifas.yml` les cambiaría el resultado sin que nadie lo pida.
  MINIMO_LPS = 173.91

  ESCALERAS = {
    "express" => [ [ 0, nil, 7.50 ] ],
    "cer"     => [ [ 0, 50.5, 4.50 ], [ 50.5, 100.5, 4.00 ], [ 100.5, 150.5, 3.75 ], [ 150.5, nil, 3.50 ] ],
    "cem"     => [ [ 0, 3.5, 4.50 ], [ 3.5, 100.5, 2.50 ], [ 100.5, 200.5, 2.20 ], [ 200.5, nil, 2.00 ] ],
    "cka"     => [ [ 0, nil, 4.00 ] ],
    "ckm"     => [ [ 0, 3.5, 4.00 ], [ 3.5, 13.5, 2.50 ], [ 13.5, 100.5, 1.90 ],
                   [ 100.5, 200.5, 1.75 ], [ 200.5, nil, 1.65 ] ]
  }.freeze

  setup do
    sembrar_tarifas_de_lista
    @doc = ServiciosPdf.new
  end

  # ── De dónde salen los datos ────────────────────────────────────────────

  test "trae los cinco servicios en orden" do
    assert_equal %w[express cer cem cka ckm], @doc.servicios.map(&:codigo)
  end

  test "deja afuera los Legacy aunque sigan activos" do
    # `seeds.rb` dice desactivarlos y no tienen tarifas, pero sobreviven
    # activos en la base. Con `TipoEnvio.activos` el PDF saldría con "CER
    # Legacy" adentro — ruido para quien lo revisa.
    legacy = TipoEnvio.find_by(codigo: "cer-legacy")
    legacy&.update_columns(activo: true)

    assert_not_includes @doc.servicios.map(&:codigo), "cer-legacy"
  end

  test "la escalera de CER es la de lista, con sus cuatro tramos" do
    cer = TipoEnvio.find_by(codigo: "cer")
    tramos = @doc.escalera(cer)

    assert_equal 4, tramos.size
    assert_equal({ desde: 0.0, hasta: 50.5, precio: 4.5, moneda: "USD" }, tramos.first)
    assert_nil tramos.last[:hasta], "el último tramo no tiene tope"
  end

  test "la escalera NO trae los precios de las categorias" do
    # Si tomara cualquier tarifa, la escalera mezclaría el precio de lista con
    # el de Shein o el de Personal CEC — y este documento muestra el PÚBLICO.
    cer = TipoEnvio.find_by(codigo: "cer")
    categoria = CategoriaPrecio.first
    Tarifa.create!(tipo_envio: cer, categoria_precio: categoria, desde_libras: 0,
                   precio_libra: 1.23, moneda: "USD", activo: true)

    assert_not_includes @doc.escalera(cer).map { |t| t[:precio] }, 1.23
  end

  test "la escalera deja afuera los recargos por sucursal" do
    # El precio de lista es el general. El de una sucursal concreta es una
    # excepción y confundiría al lado del otro.
    ckm = TipoEnvio.find_by(codigo: "ckm")
    Tarifa.create!(tipo_envio: ckm, sucursal: sucursales(:humuya_tgu), desde_libras: 0,
                   precio_libra: 9.99, moneda: "USD", activo: true)

    assert_not_includes @doc.escalera(ckm).map { |t| t[:precio] }, 9.99
  end

  test "EXPRESS es el unico con el minimo en dolares" do
    en_dolares = @doc.servicios.select { |t| @doc.minimo(t)&.dig(:moneda) == "USD" }

    assert_equal [ "express" ], en_dolares.map(&:codigo)
  end

  test "el minimo en lempiras se muestra con el ISV sumado" do
    # Yusef habla en L.200; la columna guarda el neto. Si el documento mostrara
    # solo el neto, él leería un número que nunca vio.
    cer = TipoEnvio.find_by(codigo: "cer")
    m = @doc.minimo(cer)

    assert_equal 173.91, m[:monto].to_f
    assert_equal 200.0, m[:con_isv].to_f
  end

  test "los acentos de modalidad y SLA van bien escritos" do
    # La base guarda "aereo" y "dias habiles" sin acento — son valores de
    # sistema, no texto para un cliente.
    h = @doc.hechos(TipoEnvio.find_by(codigo: "cer"))

    assert_equal "Aéreo", h[:modalidad]
    assert_match(/días hábiles/, h[:sla])
  end

  test "cada servicio lleva su propia segunda linea de direccion" do
    lineas = @doc.servicios.map { |t| @doc.direccion(t)[:linea2] }

    assert_equal lineas.uniq.size, lineas.size, "dos servicios comparten la línea 2"
  end

  # ── Los avisos ──────────────────────────────────────────────────────────

  test "avisa de una tarifa que apunta a una sucursal que no existe" do
    # La fila huérfana no se puede crear de verdad: hay una FK. Se simula que la
    # sucursal desapareció, que es exactamente lo que pasó en la base de
    # desarrollo — cargar fixtures desactiva la integridad referencial y deja
    # tres tarifas apuntando al vacío.
    #
    # Importa porque `Tarifa.resolver` cae a la fila genérica cuando no
    # encuentra la de la sucursal: ese recargo NUNCA se cobra, en silencio.
    ckm = TipoEnvio.find_by(codigo: "ckm")
    Tarifa.create!(tipo_envio: ckm, sucursal: sucursales(:humuya_tgu), desde_libras: 13.5,
                   precio_libra: 2.0, moneda: "USD", activo: true)

    # Se pide por `avisos` y no por el detector suelto: así también se prueba
    # que el aviso llegue a la lista que imprime la tarea.
    avisos = @doc.avisos([])

    assert_match(/NUNCA se aplica/, avisos.join("\n"))
    assert_match(/CKM/, avisos.join("\n"))
  end

  test "el aviso dice qué es lo que casi siempre pasó" do
    # "ese precio NUNCA se aplica" suena a bug de plata y manda a buscar uno.
    # No lo es: es la base de desarrollo con los fixtures de test encima. El
    # diagnóstico vivía solo en un comentario del código, así que la pista se
    # perdía y el aviso se perseguía de nuevo. Pasó dos veces.
    ckm = TipoEnvio.find_by(codigo: "ckm")
    Tarifa.create!(tipo_envio: ckm, sucursal: sucursales(:humuya_tgu), desde_libras: 13.5,
                   precio_libra: 2.0, moneda: "USD", activo: true)

    assert_match(/fixtures/, @doc.avisos([]).join("\n"))
  end

  test "sin huerfanas tampoco sale la pista" do
    # Una pista que sale siempre es ruido, y el aviso pasa a leerse en diagonal.
    assert_no_match(/fixtures/, @doc.avisos.join("\n"))
  end

  test "avisa de un servicio canonico sin tarifa de lista" do
    cka = TipoEnvio.find_by(codigo: "cka")
    Tarifa.where(tipo_envio_id: cka.id).delete_all

    assert_match(/CKA no tiene tarifa de lista/, ServiciosPdf.new.avisos.join("\n"))
  end

  test "avisa de un servicio activo que no es de los cinco" do
    TipoEnvio.find_by(codigo: "cer-legacy")&.update_columns(activo: true)

    assert_match(/NO son de los cinco/, @doc.avisos.join("\n"))
  end

  test "sin problemas no inventa avisos" do
    TipoEnvio.where.not(codigo: ServiciosPdf::CANONICOS).update_all(activo: false)
    Tarifa.where.not(sucursal_id: nil).delete_all

    assert_empty @doc.avisos
  end

  # ── Que salga ───────────────────────────────────────────────────────────

  test "el documento se genera" do
    salida = @doc.render

    assert salida.start_with?("%PDF-"), "no salió un PDF"
    assert_operator salida.bytesize, :>, 10_000
  end

  test "se genera aunque un servicio no tenga tarifas" do
    # El documento tiene que salir igual y decirlo, no reventar: si revienta,
    # nadie se entera de que falta el precio.
    Tarifa.where(tipo_envio_id: TipoEnvio.find_by(codigo: "cka").id).delete_all

    assert ServiciosPdf.new.render.start_with?("%PDF-")
  end

  test "sin la fuente avisa en vez de reventar con los acentos" do
    # Sin las TTF, Prawn cae a Helvetica y CADA acento del texto en español
    # levanta `IncompatibleStringEncoding` — a mitad del render, con un mensaje
    # que no dice nada de fuentes.
    original = PdfEntregable::FUENTES
    PdfEntregable.send(:remove_const, :FUENTES)
    PdfEntregable.const_set(:FUENTES, Rails.root.join("vendor/no_existe"))

    error = assert_raises(RuntimeError) { ServiciosPdf.new.render }
    assert_match(/DejaVuSans/, error.message)
  ensure
    PdfEntregable.send(:remove_const, :FUENTES)
    PdfEntregable.const_set(:FUENTES, original)
  end

  private

  def sembrar_tarifas_de_lista
    ESCALERAS.each do |codigo, tramos|
      tipo = TipoEnvio.find_by(codigo: codigo)
      next if tipo.nil?

      tramos.each do |desde, hasta, precio|
        Tarifa.create!(
          tipo_envio: tipo, desde_libras: desde, hasta_libras: hasta,
          precio_libra: precio, moneda: "USD", activo: true,
          # EXPRESS es el único con el mínimo en dólares. Yusef lo cerró en el
          # audio: "$10 más ISV", no los $14.95 de abril.
          minimo_monto: codigo == "express" ? 10.00 : MINIMO_LPS,
          minimo_moneda: codigo == "express" ? "USD" : "LPS"
        )
      end
    end
  end
end
