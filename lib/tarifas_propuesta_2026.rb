# PR-10.g: la tabla de precios real, la que Yusef mandó en
# `precios por categoria 2026.xlsx` (hoja **PROPUESTA**).
#
# Hasta acá el motor de tarifas (PR-10.a) corría con el backfill de la
# migración, que solo replicaba el comportamiento viejo: un precio plano por
# servicio y nada de mínimos ni escalones. Esto lo llena con los números de
# verdad.
#
# El archivo confirmó el diseño de PR-10.a punto por punto — Yusef llegó por su
# cuenta a la misma estructura (columnas NORMAL/MINIMO por categoría, un
# tarifario escalonado por rangos de libras, una fila aparte para Tegucigalpa,
# y una categoría "SIN COBRO MINIMO"). Incluso el mínimo: en la hoja ACTUAL
# estaba como 6.45 USD y en la PROPUESTA pasó a **173.91**, que es el neto sin
# ISV de los L.200 — la misma convención que ya usaba el modelo.
#
# Va en una tarea aparte y no en `db/seeds.rb` porque los precios cambian con
# el negocio: cuando Yusef mande una corrección hay que poder aplicar solo
# esto, sin correr el seed entero.
#
# Se resiembra sin miedo: la llave natural es
# (tipo_envio, categoría, sucursal, desde_libras) y las filas se actualizan en
# lugar de duplicarse.
class TarifasPropuesta2026
  # ── Categorías de la hoja ────────────────────────────────────────────────
  #
  # `Precio Normal` no es una categoría: es el precio de lista (sin categoría).
  # `Precio Tegus` y `SHEIN TGUS` tampoco: son la misma tarifa con un sobrecosto
  # de transporte a Tegucigalpa, así que van como fila con `sucursal`. Jorge:
  # es el sistema el que aplica el precio de Tegus cuando el paquete va para
  # allá, el cajero no elige nada — si no, al abrir La Ceiba habría que duplicar
  # cada categoría otra vez.
  #
  # `FAMILIA` y `REVENDEDORES` vienen con todo en cero (sin definir). Se crean
  # las categorías para que existan, pero sin tarifas: caen al precio de lista.
  CATEGORIAS = [
    { nombre: "Clientes Amigos",   columna: "CLIENTES AMIGOS" },
    { nombre: "doTERRA / Farmasi", columna: "DOTERRA FARMASI" },
    { nombre: "Personal CEC",      columna: "PERSONAL DE CEC" },
    { nombre: "Shein",             columna: "SHEIN" },
    { nombre: "Sin Cobro Mínimo",  columna: "SIN COBRO MINIMO" },
    { nombre: "Familia",           columna: "FAMILIA" },
    { nombre: "Revendedores",      columna: "REVENDEDORES" },
    # Ya existe desde el seed original, pero se lista igual: si falta, su
    # tarifa de CKM se saltaría sin que nadie se entere.
    { nombre: "Mayorista",         columna: "MAYORISTAS" }
  ].freeze

  # El mínimo general en Lempiras: L.173.91 + ISV = L.200.00 exactos.
  MINIMO_LPS = 173.91

  # ── Precio de lista — columna "Precio Normal" + los tarifarios escalonados ─
  #
  # El primer tramo de cada tarifario ("DE 0 A 1 LBS → L.200 CON ISV") no es un
  # precio por libra sino el mínimo, y el mínimo ya va en la fila completa, así
  # que ese tramo queda absorbido en el siguiente: a 1 lb de CER el cálculo da
  # $4.50 ≈ L.112, por debajo del mínimo, y se cobra L.173.91 igual.
  #
  # Los cortes de CEM y CKM en la hoja dicen "101" y "201" donde CER dice
  # "100.5" y "150.5". Se toma el patrón de CER (medias libras) para los tres:
  # si no, un paquete de 100.5 lb cae en un hueco sin tarifa.
  #
  # `precio_lista` es la columna "Precio Normal" de la matriz de arriba, que no
  # siempre coincide con el primer escalón: en CEM y CKM el tramo chico es un
  # recargo (CEM arranca en $4.50 y baja a $2.50 pasadas las 3 libras).
  LISTA = {
    # CER — aéreo con reempaque
    "cer" => {
      precio_lista: 4.50,
      minimo: { monto: MINIMO_LPS, moneda: "LPS" },
      escalones: [
        { desde: 0,     hasta: 50.5,  precio: 4.50 },
        { desde: 50.5,  hasta: 100.5, precio: 4.00 },
        { desde: 100.5, hasta: 150.5, precio: 3.75 },
        { desde: 150.5, hasta: nil,   precio: 3.50 }
      ]
    },
    # CKA — aéreo sin reempaque. Sin escalonado en la hoja: precio plano.
    "cka" => {
      precio_lista: 4.00,
      minimo: { monto: MINIMO_LPS, moneda: "LPS" },
      escalones: [ { desde: 0, hasta: nil, precio: 4.00 } ]
    },
    # EXPRESS — sin escalonado, y el único con mínimo en dólares.
    # Cierra la pregunta pendiente: el mínimo es $10, no los $14.95 de abril.
    "express" => {
      precio_lista: 7.50,
      minimo: { monto: 10.00, moneda: "USD" },
      escalones: [ { desde: 0, hasta: nil, precio: 7.50 } ]
    },
    # CEM — marítimo con reempaque
    "cem" => {
      precio_lista: 2.50,
      minimo: { monto: MINIMO_LPS, moneda: "LPS" },
      escalones: [
        { desde: 0,     hasta: 3.5,   precio: 4.50 },
        { desde: 3.5,   hasta: 100.5, precio: 2.50 },
        { desde: 100.5, hasta: 200.5, precio: 2.20 },
        { desde: 200.5, hasta: nil,   precio: 2.00 }
      ]
    },
    # CKM — marítimo sin reempaque. El único con diferencia por sucursal:
    # "DE 13.5 A 100 LIBRAS EN SPS" $1.90 vs "EN TGU" $2.00.
    "ckm" => {
      precio_lista: 1.90,
      minimo: { monto: MINIMO_LPS, moneda: "LPS" },
      escalones: [
        { desde: 0,     hasta: 3.5,   precio: 4.00 },
        { desde: 3.5,   hasta: 13.5,  precio: 2.50 },
        { desde: 13.5,  hasta: 100.5, precio: 1.90, sucursales: { "TGU" => 2.00 } },
        { desde: 100.5, hasta: 200.5, precio: 1.75 },
        { desde: 200.5, hasta: nil,   precio: 1.65 }
      ]
    }
  }.freeze

  # ── Precios por categoría ────────────────────────────────────────────────
  #
  # Precio plano: la hoja da un solo NORMAL por servicio, sin escalonado. El
  # tarifario escalonado está declarado solo para el precio de lista.
  #
  # Un MINIMO en 0 en la hoja significa "sin definir", no "mínimo de cero" —
  # se carga como `nil` (sin mínimo) y no como 0.
  #
  # Todos los montos en USD salvo el mínimo de lista.
  CATEGORIA_TARIFAS = {
    "Clientes Amigos" => {
      "cer"     => { precio: 4.20, minimo: 5.00 },
      "cka"     => { precio: 3.80, minimo: 5.00 },
      "express" => { precio: 7.00, minimo: 10.00 },
      "cem"     => { precio: 2.20 },
      "ckm"     => { precio: 1.70 }
    },
    "doTERRA / Farmasi" => {
      "cer"     => { precio: 3.50, minimo: 5.00 },
      "cka"     => { precio: 3.50, minimo: 5.00 },
      "express" => { precio: 7.00, minimo: 10.00 },
      "cem"     => { precio: 1.70 },
      "ckm"     => { precio: 1.70 }
    },
    "Personal CEC" => {
      "cer"     => { precio: 3.50 },
      "cka"     => { precio: 3.00, minimo: 3.00 },
      "express" => { precio: 6.50 },
      "cem"     => { precio: 1.80, minimo: 1.80 },
      "ckm"     => { precio: 1.40, minimo: 1.40 }
    },
    "Shein" => {
      "cer"     => { precio: 3.50 },
      "cka"     => { precio: 3.50 },
      "express" => { precio: 7.00 },
      # SHEIN TGUS: los dos marítimos suben en Tegucigalpa.
      "cem"     => { precio: 1.75, sucursales: { "TGU" => 1.90 } },
      "ckm"     => { precio: 1.75, sucursales: { "TGU" => 1.90 } }
    },
    # La razón de ser de la categoría: mismo precio de lista, sin piso.
    # Yusef: "ahí es donde entran excepciones a las reglas".
    "Sin Cobro Mínimo" => {
      "cer"     => { precio: 4.50, aplica_minimo: false },
      "cka"     => { precio: 4.00, aplica_minimo: false },
      "express" => { precio: 7.50, aplica_minimo: false },
      "cem"     => { precio: 2.50, aplica_minimo: false },
      "ckm"     => { precio: 1.90, aplica_minimo: false }
    },
    # MAYORISTAS viene casi entero en cero: el único servicio con precio
    # definido es CKM. Los otros cuatro se quedan como estaban (backfill de
    # PR-10.a) hasta que Yusef los llene.
    "Mayorista" => {
      "ckm" => { precio: 1.50 }
    }
  }.freeze

  NOTA = "Precios PROPUESTA 2026 (Yusef, precios por categoria 2026.xlsx)".freeze

  def self.sembrar!(verbose: false)
    new(verbose: verbose).sembrar!
  end

  def initialize(verbose: false)
    @verbose = verbose
    @creadas = 0
    @actualizadas = 0
    @sin_cambio = 0
  end

  def sembrar!
    ActiveRecord::Base.transaction do
      crear_categorias
      sembrar_lista
      sembrar_categorias
      sincronizar_tipo_envio_precio_libra
    end

    log "  ✓ tarifas: #{@creadas} creadas, #{@actualizadas} actualizadas, #{@sin_cambio} sin cambio"
    { creadas: @creadas, actualizadas: @actualizadas, sin_cambio: @sin_cambio }
  end

  private

  def crear_categorias
    CATEGORIAS.each do |attrs|
      # `precio_libra_aereo` / `precio_libra_maritimo` quedan en nil a
      # propósito: son el mecanismo viejo (dos modalidades para cinco
      # servicios) y tenerlos llenos daría dos fuentes de verdad para el mismo
      # precio. Sin tarifa, el fallback usa el precio de lista.
      CategoriaPrecio.find_or_create_by!(nombre: attrs[:nombre])
    end
    log "  ✓ #{CategoriaPrecio.count} categorías de precio"
  end

  def sembrar_lista
    LISTA.each do |codigo, spec|
      tipo = tipo_envio!(codigo) or next

      spec[:escalones].each do |escalon|
        upsert(
          tipo_envio: tipo,
          categoria: nil,
          sucursal: nil,
          escalon: escalon,
          precio: escalon[:precio],
          minimo: spec[:minimo]
        )

        (escalon[:sucursales] || {}).each do |codigo_sucursal, precio|
          sucursal = sucursal!(codigo_sucursal) or next
          upsert(
            tipo_envio: tipo,
            categoria: nil,
            sucursal: sucursal,
            escalon: escalon,
            precio: precio,
            minimo: spec[:minimo]
          )
        end
      end
    end
  end

  def sembrar_categorias
    CATEGORIA_TARIFAS.each do |nombre, servicios|
      categoria = CategoriaPrecio.find_by(nombre: nombre)
      next log("  ⚠ categoría no encontrada: #{nombre}") if categoria.nil?

      servicios.each do |codigo, spec|
        tipo = tipo_envio!(codigo) or next
        escalon = { desde: 0, hasta: nil }
        minimo  = spec[:minimo] && { monto: spec[:minimo], moneda: "USD" }

        upsert(
          tipo_envio: tipo, categoria: categoria, sucursal: nil,
          escalon: escalon, precio: spec[:precio], minimo: minimo,
          aplica_minimo: spec.fetch(:aplica_minimo, true)
        )

        (spec[:sucursales] || {}).each do |codigo_sucursal, precio|
          sucursal = sucursal!(codigo_sucursal) or next
          upsert(
            tipo_envio: tipo, categoria: categoria, sucursal: sucursal,
            escalon: escalon, precio: precio, minimo: minimo,
            aplica_minimo: spec.fetch(:aplica_minimo, true)
          )
        end
      end
    end
  end

  # `tipo_envios.precio_libra` es el respaldo cuando no hay tarifa cargada.
  # Quedó desalineado con la propuesta (EXPRESS 8.00 → 7.50, CKM 1.50 → 1.90)
  # y un fallback que cobra distinto que la tarifa es peor que no tenerlo.
  def sincronizar_tipo_envio_precio_libra
    LISTA.each do |codigo, spec|
      tipo = tipo_envio!(codigo) or next
      precio = spec[:precio_lista]
      next if tipo.precio_libra.to_d == precio.to_d

      log "  ↻ #{tipo.nombre}.precio_libra #{tipo.precio_libra.to_f} → #{precio}"
      tipo.update!(precio_libra: precio)
    end
  end

  # Llave natural: (tipo_envio, categoría, sucursal, desde_libras). Sin
  # `cliente` ni `proveedor` porque esta tabla no trae excepciones de esas —
  # se cargan a mano desde /servicios.
  def upsert(tipo_envio:, categoria:, sucursal:, escalon:, precio:, minimo:, aplica_minimo: true)
    tarifa = Tarifa.find_or_initialize_by(
      tipo_envio_id: tipo_envio.id,
      categoria_precio_id: categoria&.id,
      cliente_id: nil,
      proveedor_id: nil,
      sucursal_id: sucursal&.id,
      desde_libras: escalon[:desde]
    )
    nueva = tarifa.new_record?

    tarifa.assign_attributes(
      hasta_libras:  escalon[:hasta],
      precio_libra:  precio,
      moneda:        "USD",
      minimo_monto:  minimo&.dig(:monto),
      minimo_moneda: minimo&.dig(:moneda),
      aplica_minimo: aplica_minimo,
      activo:        true,
      notas:         NOTA
    )

    if nueva
      tarifa.save!
      @creadas += 1
    elsif tarifa.changed?
      tarifa.save!
      @actualizadas += 1
    else
      @sin_cambio += 1
    end
  end

  def tipo_envio!(codigo)
    @tipos ||= {}
    @tipos[codigo] ||= TipoEnvio.find_by(codigo: codigo)
    log("  ⚠ tipo de envío no encontrado: #{codigo}") if @tipos[codigo].nil?
    @tipos[codigo]
  end

  def sucursal!(codigo)
    @sucursales ||= {}
    @sucursales[codigo] ||= Sucursal.find_by(codigo: codigo)
    log("  ⚠ sucursal no encontrada: #{codigo}") if @sucursales[codigo].nil?
    @sucursales[codigo]
  end

  def log(mensaje)
    puts mensaje if @verbose
    nil
  end
end
