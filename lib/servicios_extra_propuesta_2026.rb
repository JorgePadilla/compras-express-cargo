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
    "RETENIDO MIAMI" => 'valor 5 con nota "pasarlo a dolares": no se sabe si el 5 ya es dolares o falta convertirlo',
    "SERVICIO DE ENTRADA Y SALIDA" => 'valor 10 / minimo 5 con nota "pasarlo a dolares" — misma duda',
    "RECOLECTA MIAMI" => "choca con `TarifaRecolecta`, que Yusef mismo pidio por zona en vez de los $35 fijos",
    "AJUSTE" => "valor 1 sin moneda ni definicion de que ajusta",
    "ENTREGA LOCAL" => "valor 1 sin moneda; el titulo dice L1 pero no hay nota que lo confirme",
    "CONSOLIDANDO EN MIAMI" => "valor 1 sin moneda",
    "FLETE MEXICO" => "RP-13a lo cerro: $5 por libra o libra volumetrica + ISV, sin minimo; lo carga el equipo por /servicios_extra",
    "FLETE" => "es el flete del paquete, que vive en `Tarifa` — no es un servicio extra",
    "PRODUCTO EJEMPLO / EN DOLARES" => "datos de prueba, Jorge ya lo confirmo"
  }.freeze

  NOTA = "Cargos PROPUESTA 2026 (Yusef, precios por categoria 2026.xlsx)".freeze

  # ── Cambio de servicio ──────────────────────────────────────────────────
  #
  # Este no salió de la hoja: salió del audio del 2026-08-08, donde Yusef lo
  # dijo con todas las letras.
  #
  #   "Es un ajuste que se le hace por hacer cambio de servicio que son los
  #    **100 lempiras**. Yo te lo puse que eran 5."
  #
  # Estaba cargado en **$15 USD**, o sea ~L.373 con ISV: **3.7× de más**. Y no
  # es un cargo que alguien elige a mano — `PreFactura` lo agrega solo cuando
  # el paquete trae `solicito_cambio_servicio`, y de ahí pasa a la nota de
  # débito al facturar. Salía solo, a casi cuatro veces su precio.
  #
  # Va con el ISV **adentro**, al revés que los cinco de `CARGOS`. No es un
  # descuido: los de la hoja van netos porque la hoja dice "PRECIOS NO INCLUYEN
  # IMPUESTOS", y este vino del audio, donde Yusef habla del precio final que
  # paga el cliente. Con el flag en true el CRUD le muestra **100** — su número
  # — y `precio_venta_sin_isv` mete los 86.96 a la línea. Es el mismo criterio
  # que `Tarifa#minimo_monto_con_isv`, que lo deja escribir 200 y guarda 173.91.
  #
  # Yusef puede seguir ajustándolo desde el CRUD: "como esto es editable,
  # nosotros lo vamos a cambiar de acuerdo a lo que cuadremos al final".
  CAMBIO_SERVICIO = {
    codigo: "CAMBIO_SERVICIO",
    precio: 100.00,
    moneda: "LPS",
    incluye_isv: true
  }.freeze

  # Corrige la fila que YA existe. El seed usa `find_or_create_by!`, así que
  # editarlo no toca las bases donde el cargo ya está cargado — que es
  # justamente donde importa.
  def self.corregir_cambio_servicio!(verbose: false)
    s = ServicioExtra.find_by(codigo: CAMBIO_SERVICIO[:codigo])
    return { corregido: false, motivo: :no_existe } if s.nil?

    antes = "#{s.precio_venta} #{s.moneda}"
    s.assign_attributes(
      precio_venta: CAMBIO_SERVICIO[:precio],
      moneda: CAMBIO_SERVICIO[:moneda],
      precio_incluye_isv: CAMBIO_SERVICIO[:incluye_isv]
    )
    return { corregido: false, motivo: :ya_estaba } unless s.changed?

    s.save!
    puts "  ✓ cambio de servicio: #{antes} → #{s.precio_venta} #{s.moneda} (Yusef 2026-08-08)" if verbose
    { corregido: true, antes: antes }
  end

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

    # Va acá y no en una tarea aparte para que el deploy no dependa de que
    # alguien se acuerde de correr dos comandos.
    cambio = corregir_cambio_servicio!(verbose: verbose)

    if verbose
      puts "  ✓ cargos: #{creados} creados, #{actualizados} actualizados"
      puts "  ⬜ #{PENDIENTES.size} quedan pendientes de que Yusef confirme:"
      PENDIENTES.each { |nombre, motivo| puts "     · #{nombre}: #{motivo}" }
    end

    { creados: creados, actualizados: actualizados, pendientes: PENDIENTES.size,
      cambio_servicio: cambio }
  end
end
