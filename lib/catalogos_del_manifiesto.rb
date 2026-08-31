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

  # Los diez tamaños de la pantalla vieja, en su orden.
  #
  # Las medidas van en nil salvo «Mini D»: la pantalla vieja muestra 595.78 de
  # volumen para 46×43×50, que es exactamente lo que da `VolumetricoCalculator`
  # con su divisor de 166, así que es la única derivable. Las otras nueve las
  # mide Miami con la cinta — y de todos modos se editan caja por caja, porque
  # *"ellos vienen y marcan EH y le modifican una medida, porque la cortan: le
  # decimos «EH cortada»"*.
  #
  # «Especificar» no lleva medidas **a propósito**: es la opción para la caja
  # que no entra en ningún tamaño.
  TAMANOS = [
    { nombre: "Especificar",  position: 1 },
    { nombre: "EH",           position: 2 },
    { nombre: "D",            position: 3 },
    { nombre: "22 Cubo",      position: 4 },
    { nombre: "18 Cubo",      position: 5 },
    { nombre: "D G",          position: 6 },
    { nombre: "EH G",         position: 7 },
    { nombre: "E",            position: 8 },
    { nombre: "Mini D",       position: 9, alto: 46, largo: 43, ancho: 50 },
    { nombre: "Mini D Doble", position: 10 }
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
    end

    creados
  end
end
