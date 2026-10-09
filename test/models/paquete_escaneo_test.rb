require "test_helper"

# PR-C6.21: la escalera con la que se resuelve un tracking que entró por la
# pistola de códigos de barras.
#
# Yusef, 2026-08-08, escaneando paquetes reales de Amazon, UPS, FedEx y USPS
# uno por uno delante de Jorge:
#
#   "El tracking de USPS **solo es desde donde dice 92**... esto es lo que el
#    cliente recibe de tracking y **esto es lo que le escanea el sistema**."
#   "Ahora el sistema debe buscar en esto también [el tracking secundario],
#    debe buscar en la base, y **eso no estaba**."
#
# Antes era `where(tracking: valor)`: exacto, case-sensitive, una sola columna.
# Tres formas distintas de no encontrar un paquete que sí existe — y las tres
# las vio fallar en vivo. Cuando el escaneo no encuentra el paquete esperado,
# Miami graba uno nuevo al lado y el bulto queda duplicado en el sistema.
class PaqueteEscaneoTest < ActiveSupport::TestCase
  # El par real de USPS: la etiqueta lleva el código completo (con el ruteo
  # `420` + ZIP adelante) y el cliente pre-alerta solo la cola, que es lo que
  # le muestra el correo.
  ESCANEADO_USPS = "420331439261091390000806743500382574".freeze
  TRACKING_USPS  = "9261091390000806743500382574".freeze

  test "encuentra por el tracking exacto" do
    paquete = paquetes(:recibido)

    assert_equal [ paquete ], Paquete.buscar_escaneado(paquete.tracking).to_a
  end

  test "no le importan las mayusculas" do
    # `Paquete` NO normaliza el tracking al guardar (a diferencia de
    # `PreAlertaPaquete`), así que en la base hay minúsculas de verdad.
    #
    # El tracking va corto a propósito: con uno largo, la rama de sufijo
    # rescataría el caso aunque el escalón exacto estuviera roto, y el test
    # pasaría sin estar probando lo que dice probar.
    paquete = crear(tracking: "tba1234")

    assert_equal [ paquete ], Paquete.buscar_escaneado("TBA1234").to_a
  end

  test "ni los espacios de los costados" do
    paquete = paquetes(:recibido)

    assert_equal [ paquete ], Paquete.buscar_escaneado("  #{paquete.tracking}  ").to_a
  end

  test "encuentra por el tracking secundario" do
    # "el sistema debe buscar en esto también, y eso no estaba".
    paquete = crear(tracking: "TBA000000000001", tracking_secundario: "1ZSEC99XX0123456789")

    assert_equal [ paquete ], Paquete.buscar_escaneado("1ZSEC99XX0123456789").to_a
  end

  test "el codigo largo de la pistola encuentra el tracking del cliente" do
    paquete = crear(tracking: TRACKING_USPS)

    assert_equal [ paquete ], Paquete.buscar_escaneado(ESCANEADO_USPS).to_a
  end

  test "el sufijo se compara entero, no como pedazo suelto" do
    # `9261...574` tiene que ser el FINAL del escaneo. Un tracking que aparece
    # en medio del código no es el mismo paquete.
    crear(tracking: "0080674350038257")

    assert_empty Paquete.buscar_escaneado(ESCANEADO_USPS).to_a
  end

  test "un tracking corto no cae por sufijo" do
    # Sin este piso, un paquete con tracking `2574` se comería cualquier
    # escaneo que termine en esos cuatro dígitos.
    crear(tracking: "82574")

    assert_empty Paquete.buscar_escaneado(ESCANEADO_USPS).to_a
  end

  test "un escaneo corto tampoco dispara la busqueda por sufijo" do
    crear(tracking: TRACKING_USPS)

    assert_empty Paquete.buscar_escaneado("500382574").to_a
  end

  test "el exacto le gana al sufijo" do
    # Si existen los dos, el escaneo cae en el que ES ese código, no en el que
    # termina así. Un match exacto no puede quedar tapado por uno difuso.
    exacto = crear(tracking: ESCANEADO_USPS)
    crear(tracking: TRACKING_USPS)

    assert_equal [ exacto ], Paquete.buscar_escaneado(ESCANEADO_USPS).to_a
  end

  test "el tracking le gana al secundario" do
    por_tracking = crear(tracking: "1ZCOLISION0123456789")
    crear(tracking: "TBA000000000002", tracking_secundario: "1ZCOLISION0123456789")

    assert_equal [ por_tracking ], Paquete.buscar_escaneado("1ZCOLISION0123456789").to_a
  end

  test "un guion bajo no se comporta como comodin" do
    # De ahí que el sufijo use `RIGHT(...)` y no `LIKE '%' || tracking`: en SQL
    # el `_` matchea cualquier carácter. El formato del tracking prohíbe `%`
    # pero **sí** permite `_`, así que el agujero era alcanzable de verdad.
    crear(tracking: "AB_CD_EF_GH")

    assert_empty Paquete.buscar_escaneado("ABZCDZEFZGH").to_a
  end

  test "sin termino no devuelve todo" do
    assert_empty Paquete.buscar_escaneado("").to_a
    assert_empty Paquete.buscar_escaneado(nil).to_a
  end

  test "se encadena y cada escalon respeta el alcance de quien llama" do
    # El caso que importa: el exacto existe pero está fuera del alcance
    # (ya vinculado, terminal, lo que sea). La escalera no puede cortarse ahí
    # — tiene que seguir al sufijo dentro del alcance pedido.
    fuera = crear(tracking: ESCANEADO_USPS, estado: "entregado")
    dentro = crear(tracking: TRACKING_USPS, estado: "recibido_miami")

    encontrados = Paquete.where(estado: "recibido_miami").buscar_escaneado(ESCANEADO_USPS).to_a

    assert_equal [ dentro ], encontrados
    assert_not_includes encontrados, fuera
  end

  private

  def crear(attrs)
    Paquete.create!({
      cliente: clientes(:juan),
      tipo_envio: tipo_envios(:cer),
      descripcion: "Paquete de prueba",
      peso: 5,
      estado: "recibido_miami",
      user: users(:digitador)
    }.merge(attrs))
  end
end
