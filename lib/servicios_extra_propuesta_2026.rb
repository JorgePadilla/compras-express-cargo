# PR-10.i: los cargos que NO son flete, de la hoja PROPUESTA de Yusef.
#
# Su tabla trae 16 filas además de los 5 tipos de envío. **Acá van solo cinco**:
# los que el propio texto de la hoja define sin dejar dudas. El resto necesita
# que Yusef confirme la moneda, y cargarlos adivinando sería peor que no
# cargarlos — son montos que se le cobran al cliente.
#
# Por qué queda la duda: la hoja tiene una leyenda de colores
# ("**PRECIOS EN $" / "**PRECIOS EN LEMPIRAS") pero **las celdas de precio no
# están coloreadas** — la leyenda se declaró y nunca se aplicó. Se verificó
# leyendo los rellenos del XLSX: todas las celdas de la columna de precio tienen
# relleno nulo.
#
# Lo que sí es global y sí aplica: "**PRECIOS NO INCLUYEN IMPUESTOS" (fila 30).
# Por eso los cinco entran con `precio_incluye_isv: false` — el ISV se suma al
# totalizar, una sola vez.
class ServiciosExtraPropuesta2026
  # Cada entrada dice **de dónde sale la certeza**. Si no se puede escribir esa
  # justificación, el cargo no va acá: va a la lista de pendientes.
  CARGOS = [
    {
      codigo: "ENTREGA_NACIONAL",
      descripcion: "Entrega nacional",
      precio: 86.96, moneda: "LPS",
      # El título de la fila dice "ENTREGA NACIONAL L100" y 86.96 × 1.15 = 100.00
      # exactos. La moneda y el neto quedan confirmados por la propia aritmética.
      certeza: "el titulo dice L100 y 86.96 + ISV = L.100.00 exactos"
    },
    {
      codigo: "COMPRA_ONLINE",
      descripcion: "Compra online",
      precio: 1.00, moneda: "USD",
      certeza: 'nota de Yusef en la fila: "ponerlo $1 mas isv"'
    },
    {
      codigo: "MANEJO_DESTINO",
      descripcion: "Manejo y gastos de destino",
      precio: 1.00, moneda: "LPS",
      certeza: 'nota de Yusef en la fila: "ponerlo lps1 mas isv"'
    },
    {
      codigo: "FLETE_INTL_UPS",
      descripcion: "Flete internacional UPS",
      precio: 1.00, moneda: "USD",
      certeza: 'el titulo de la fila dice "FLETE INTERNACIONAL UPS $1"'
    },
    {
      codigo: "RETORNADO_MIAMI",
      descripcion: "Retornado en Miami",
      precio: 5.00, moneda: "USD",
      certeza: 'nota de Yusef en la fila: "todo en $"'
    }
  ].freeze

  # Los que quedan afuera, con el motivo. Se imprimen al correr la tarea para
  # que no se pierdan de vista.
  PENDIENTES = {
    "CAMBIO DE SERVICIO" => 'el titulo dice L100 pero el valor es 5 y la nota "pasarlo a dolares" — ' \
                            "ademas ya existe cargado a $15, que es 3x. Es el que se auto-genera en nota de debito",
    "RETENIDO MIAMI" => 'valor 5 con nota "pasarlo a dolares": no se sabe si el 5 ya es dolares o falta convertirlo',
    "SERVICIO DE ENTRADA Y SALIDA" => 'valor 10 / minimo 5 con nota "pasarlo a dolares" — misma duda',
    "RECOLECTA MIAMI" => "choca con `TarifaRecolecta`, que Yusef mismo pidio por zona en vez de los $35 fijos",
    "AJUSTE" => "valor 1 sin moneda ni definicion de que ajusta",
    "ENTREGA LOCAL" => "valor 1 sin moneda; el titulo dice L1 pero no hay nota que lo confirme",
    "CONSOLIDANDO EN MIAMI" => "valor 1 sin moneda",
    "FLETE MEXICO" => "valor 5 / minimo 6 sin moneda",
    "FLETE" => "es el flete del paquete, que vive en `Tarifa` — no es un servicio extra",
    "PRODUCTO EJEMPLO / EN DOLARES" => "datos de prueba, Jorge ya lo confirmo"
  }.freeze

  NOTA = "Cargos PROPUESTA 2026 (Yusef, precios por categoria 2026.xlsx)".freeze

  def self.sembrar!(verbose: false)
    creados = actualizados = 0

    CARGOS.each_with_index do |c, i|
      s = ServicioExtra.find_or_initialize_by(codigo: c[:codigo])
      nuevo = s.new_record?
      s.assign_attributes(
        descripcion: c[:descripcion],
        precio_venta: c[:precio],
        moneda: c[:moneda],
        # "**PRECIOS NO INCLUYEN IMPUESTOS" — el ISV se suma al totalizar.
        precio_incluye_isv: false,
        costo: s.costo || 0,
        position: 10 + i,
        activo: true,
        notas: "#{NOTA}. Certeza: #{c[:certeza]}"
      )
      next unless s.changed? || nuevo

      s.save!
      nuevo ? creados += 1 : actualizados += 1
    end

    if verbose
      puts "  ✓ cargos: #{creados} creados, #{actualizados} actualizados"
      puts "  ⬜ #{PENDIENTES.size} quedan pendientes de que Yusef confirme:"
      PENDIENTES.each { |nombre, motivo| puts "     · #{nombre}: #{motivo}" }
    end

    { creados: creados, actualizados: actualizados, pendientes: PENDIENTES.size }
  end
end
