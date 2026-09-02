require "test_helper"

# El menú se lee en el orden del trabajo.
#
# Jorge, 2026-09-01: *"en los menú pongamos por orden de proceso los botones,
# links de logística"*. Es la misma idea con la que se rearmó la pantalla de
# manifiestos (`PR-I`, *"la pantalla en el orden del trabajo"*), aplicada al
# sidebar: quien abre el menú tendría que poder seguirlo de arriba abajo igual
# que sigue el día, sin tener que saberse el flujo de antemano.
#
# Dijo *"los menú"*, en plural, así que son **los dos**: el de admin y el del
# portal del cliente. Arreglar uno solo es el bug que más se repite en este
# repo.
#
# ── Por qué esto es un lint y no un comentario ─────────────────────────────
#
# Porque el orden de un menú es exactamente la clase de cosa que se desordena
# sola: el link nuevo se agrega **al final del grupo**, que es donde queda el
# cursor. Nadie decide moverlo; simplemente nadie decide *no* hacerlo. Sin algo
# que lo trabe, este arreglo dura hasta la próxima pantalla que se enchufe.
#
# El lint no inventa el orden: lo copia del proceso que ya está escrito en
# `lib/procesos_pdf.rb` (`CAMINO_HONDURAS`: pre-factura → factura → pago →
# entrega).
class OrdenDelMenuTest < ActiveSupport::TestCase
  ADMIN   = "app/views/layouts/_sidebar_admin.html.erb".freeze
  CLIENTE = "app/views/layouts/_sidebar_cliente.html.erb".freeze

  # Cada grupo, en el orden en que ocurre el trabajo. Lo transversal —lo que no
  # es un paso sino una consulta— va al final, y se anota como tal.
  #
  # `seccion: nil` significa el archivo entero: el sidebar del cliente es una
  # lista plana, sin grupos.
  ORDEN = {
    "Miami" => {
      archivo: ADMIN, seccion: "Miami", rutas: [
        "etiquetar_path",             # llega el paquete y se etiqueta
        "new_entrega_personal_path",  # el otro mostrador: lo que el cliente retira ahí
        "clientes_path"               # transversal: se consulta, no es un paso
      ]
    },
    "Logistica" => {
      archivo: ADMIN, seccion: "Logistica", rutas: [
        "pre_alertas_path",           # el cliente avisa que viene, antes que nada
        "manifiestos_path",           # Miami lo arma y lo envía
        "guias_aduana_index_path",    # San Pedro le pone guía y fecha al que salió
        "recepcion_carga_index_path", # llegó: se escanean las cajas
        "paquetes_path"               # transversal: el listado de todo
      ]
    },
    "Facturacion y Cobro" => {
      archivo: ADMIN, seccion: "Facturacion y Cobro", rutas: [
        "cotizaciones_path",          # se cotiza antes de pre-facturar
        "pre_facturas_path",
        "ventas_path",                # la factura
        "recibos_path",               # el pago
        "notas_debito_path",          # de acá abajo, ajustes posteriores
        "notas_credito_path",
        "financiamientos_path"
      ]
    },
    # El mismo recorrido, contado desde el cliente: avisa que viene, lo ve
    # llegar, cotiza, le facturan, paga, lo recibe.
    "Portal del cliente" => {
      archivo: CLIENTE, seccion: nil, rutas: [
        "cuenta_pre_alertas_path",
        "cuenta_cotizaciones_path",
        "cuenta_facturas_path",
        "cuenta_recibos_path",
        "cuenta_entregas_path",       # la entrega va pegada al pago, no tras las notas
        "cuenta_notas_debito_path",
        "cuenta_notas_credito_path",
        "cuenta_financiamientos_path"
      ]
    }
  }.freeze

  ORDEN.each do |grupo, spec|
    test "el grupo #{grupo} va en orden de proceso" do
      links = links_de(spec)

      real = spec[:rutas].select { |ruta| indice(links, ruta) }
                         .sort_by { |ruta| indice(links, ruta) }

      assert_equal spec[:rutas], real, <<~MSG
        El grupo «#{grupo}» dejó de leerse en el orden del trabajo.

        Se espera:  #{spec[:rutas].join(" → ")}
        Está:       #{real.join(" → ")}

        Si el proceso cambió de verdad, cambiá ORDEN acá y contá por qué. Si es
        un link nuevo que quedó al final del grupo porque ahí estaba el cursor,
        movelo al lugar que le toca en el recorrido.
      MSG
    end
  end

  # El contrapeso: si el barrido deja de encontrar los bloques —porque el
  # partial se reescribe o los títulos cambian—, los tests de arriba pasarían
  # mirando una lista vacía, contentos y sin haber comprobado nada.
  test "el barrido de verdad encuentra los cuatro grupos" do
    ORDEN.each do |grupo, spec|
      links = links_de(spec)

      refute_empty links, "no se encontró el bloque «#{grupo}»"

      faltan = spec[:rutas].reject { |ruta| indice(links, ruta) }
      assert_empty faltan, <<~MSG
        Estas rutas de «#{grupo}» ya no están en su bloque del menú. Si la
        pantalla se movió de grupo o se borró, actualizá ORDEN.

        #{faltan.join("\n")}
      MSG
    end
  end

  private

  # Solo las líneas de `sidebar_link`, en orden. Mirar el texto crudo haría que
  # un `_path` **nombrado en un comentario** contara como si fuera el link, y
  # este partial está lleno de comentarios que nombran rutas.
  def links_de(spec)
    cuerpo = File.read(Rails.root.join(spec[:archivo]))
    cuerpo = seccion(cuerpo, spec[:seccion]) if spec[:seccion]

    cuerpo.lines.select { |l| l.include?("sidebar_link") }
  end

  def indice(links, ruta)
    links.index { |l| l.include?(ruta) }
  end

  # El texto de un `sidebar_section "X" do … end`, hasta el arranque del
  # siguiente `sidebar_section` (o el final del archivo).
  def seccion(cuerpo, titulo)
    arranque = cuerpo.index(%(sidebar_section "#{titulo}"))
    return "" if arranque.nil?

    resto = cuerpo[arranque..]
    fin = resto.index("sidebar_section", 1) || resto.length
    resto[0...fin]
  end
end
