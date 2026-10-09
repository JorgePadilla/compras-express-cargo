# C21-08 · Los cuatro catálogos del manifiesto, en un solo lugar.
#
# ── Por qué esto existe y no es solo `db/seeds.rb` ────────────────────────
#
# El deploy de staging **solo migra, no siembra**
# (`render.yaml` → `preDeployCommand: bundle exec rails db:migrate`), así que un
# catálogo nuevo nace vacío allá y se queda vacío hasta que alguien corra
# `db:seed` a mano. Fue exactamente lo que pasó: `PR-M1` estrenó tres catálogos,
# `PR-M10` les puso semilla, y en staging siguieron en blanco — Jorge:
# *"nos faltaron los seeds de los catálogos, solo empresas proveedoras tenemos,
# los otros 3 están vacíos"*.
#
# La salida es una **migración de datos**, que sí corre sola en cada deploy. Y
# para que la migración y `db/seeds.rb` no se separen —que es el bug recurrente
# de este repo— la lista vive acá y las dos la leen.
#
# ── Es semilla de arranque, no verdad ─────────────────────────────────────
#
# Los nombres salen de lo que Yusef nombró en la reunión del 2026-08-29 y de la
# pantalla vieja. Todo lo demás lo carga su equipo por el CRUD:
# *"entre más cosas nos dejes crear, menos te molestaremos"*. Por eso va con
# `find_or_create_by!`: no pisa nada de lo que hayan cargado.
module CatalogosDelManifiesto
  # Las que mueven la carga. Ya venían desde la Fase 1.
  EMPRESAS = [ "PRONTO CARGO", "SERCARGO", "GENESIS" ].freeze

  # El tipo de envío **del proveedor** — no confundir con el nuestro
  # (CER/CKA/CEM/CKM/EXPRESS). Los dos que nombró mirando el impreso.
  TIPOS_DEL_PROVEEDOR = [ "AEREO EXPRESS", "CKM MARITIMO" ].freeze

  # *"Qué consignatario somos nosotros."*
  CONSIGNATARIOS = [ "CORPORACION KARSAM" ].freeze

  # Los diez tamaños de la pantalla vieja, en su orden y **con sus medidas**.
  #
  # Las medidas salieron del sistema viejo el **2026-09-05**: viven en el
  # viewmodel `TamanoCajasPredefinidoVM` que el editor de manifiestos publica en
  # la página, y se leyeron de ahí con Jorge mirando. Hasta ese día iban en nil
  # salvo «Mini D», que era la única derivable —la pantalla vieja muestra 595.78
  # de volumen para 46×43×50—; el dato de verdad la confirmó exacta.
  #
  # **El orden es alto × largo × ancho**, el mismo del formulario viejo. Ojo con
  # la foto de la etiqueta de `C21-05`, que para «EH» muestra `23x23x36`: es la
  # misma caja escrita en otro orden (23 × 36 × 23), y el producto —y por lo
  # tanto el volumen— da igual. No hay dos EH distintas.
  #
  # La «Dimensión» del sistema viejo **no se guarda**: es alto×largo×ancho ÷ 166,
  # o sea exactamente `VolumetricoCalculator::DIVISOR_LB`. Verificado contra la
  # pantalla: Mini D da 595.78 y EH 114.72, clavados. Guardarla sería tener el
  # mismo número en dos lugares con permiso para separarse.
  #
  # Y siguen siendo **un punto de partida, no un valor fijo**: se editan caja por
  # caja, porque *"ellos vienen y marcan EH y le modifican una medida, porque la
  # cortan: le decimos «EH cortada»"* (`C21-04`).
  #
  # «Especificar» no lleva medidas **a propósito**: es la opción para la caja que
  # no entra en ningún tamaño.
  TAMANOS = [
    { nombre: "Especificar",  position: 1 },
    { nombre: "EH",           position: 2,  alto: 23, largo: 36, ancho: 23 },
    { nombre: "D",            position: 3,  alto: 44, largo: 56, ancho: 42 },
    { nombre: "22 Cubo",      position: 4,  alto: 22, largo: 22, ancho: 22 },
    { nombre: "18 Cubo",      position: 5,  alto: 18, largo: 18, ancho: 18 },
    { nombre: "D G",          position: 6,  alto: 45, largo: 58, ancho: 42 },
    { nombre: "EH G",         position: 7,  alto: 24, largo: 36, ancho: 23 },
    { nombre: "E",            position: 8,  alto: 25, largo: 41, ancho: 28 },
    { nombre: "Mini D",       position: 9,  alto: 46, largo: 43, ancho: 50 },
    # «Es cuando llevan dos de esas» — y la cuenta cierra: 86 de alto son dos
    # Mini D encimadas, con el traslape.
    { nombre: "Mini D Doble", position: 10, alto: 86, largo: 43, ancho: 50 }
  ].freeze

  # Idempotente: se puede correr mil veces. Devuelve cuántas filas creó de cada
  # cosa, para que el que la llama pueda decir algo útil.
  def self.sembrar!
    creados = Hash.new(0)

    EMPRESAS.each do |nombre|
      creados[:empresas] += 1 if EmpresaManifiesto.find_or_create_by!(nombre: nombre) { |e| e.activo = true }.previously_new_record?
    end

    TIPOS_DEL_PROVEEDOR.each.with_index(1) do |nombre, i|
      registro = TipoEnvioProveedor.find_or_create_by!(nombre: nombre) do |t|
        t.position = i
        t.activo = true
      end
      creados[:tipos] += 1 if registro.previously_new_record?
    end

    CONSIGNATARIOS.each do |nombre|
      creados[:consignatarios] += 1 if Consignatario.find_or_create_by!(nombre: nombre) { |c| c.activo = true }.previously_new_record?
    end

    TAMANOS.each do |attrs|
      registro = TamanoCaja.find_or_create_by!(nombre: attrs[:nombre]) do |t|
        t.position = attrs[:position]
        t.alto  = attrs[:alto]
        t.largo = attrs[:largo]
        t.ancho = attrs[:ancho]
        t.activo = true
      end
      creados[:tamanos] += 1 if registro.previously_new_record?

      # Las medidas se **rellenan** si el tamaño ya existía sin ellas.
      #
      # Los diez se sembraron el 2026-08-31 con las medidas en nil, porque
      # todavía no las teníamos. `find_or_create_by!` solo corre su bloque al
      # **crear**, así que sin esto los ocho que ya están en la base se quedarían
      # vacíos para siempre y el dato que se sacó del sistema viejo no llegaría
      # a nadie.
      #
      # Solo rellena lo que está en nil: si Miami ya midió una caja y corrigió
      # el catálogo a mano, esa medida gana. El seeder no le pisa el dato a
      # quien lo tiene de primera mano.
      faltantes = %i[alto largo ancho].select { |c| registro.public_send(c).nil? && attrs[c].present? }
      next if faltantes.empty?

      registro.update!(faltantes.index_with { |c| attrs[c] })
      creados[:tamanos_medidos] += 1
    end

    creados
  end
end
