require "test_helper"

# PR-P.5 · C30-17 · Qué contesta la pistola en «Auditar pre-factura».
#
# Yusef: *"escanear cualquiera de estas: automáticamente… jala los tres
# volúmenes… y ahora te dice escanear los paquetes que van con esto"* · *"sí,
# pertenece"*. Y cada rechazo con su porqué.
class AuditoriaDeTandaTest < ActiveSupport::TestCase
  setup do
    @user = users(:supervisor_prefactura)
    @cliente = clientes(:juan)
    @cer = tipo_envios(:cer)
    @manifiesto = manifiestos(:enviado)
    @manifiesto.update_columns(estado: "en_aduana")
    Tarifa.delete_all
    Tarifa.create!(tipo_envio: @cer, precio_libra: 4.50, moneda: "USD")
    @hoja = HojaDePreparacion.new(modo: "nuevas", tipo_envio_ids: [ @cer.id ], manifiesto_ids: [ @manifiesto.id ])
  end

  def caja(cliente: @cliente, tipo_envio: @cer, manifiesto: @manifiesto, **extra)
    Paquete.create!(tracking: "1ZAUD#{SecureRandom.hex(5).upcase}", cliente: cliente, tipo_envio: tipo_envio,
                    sucursal_recepcion: sucursales(:miami), manifiesto: manifiesto,
                    estado: "en_aduana", descripcion: "Zapatos", peso: 2, **extra)
  end

  def medir(cajas, *volumenes)
    MedirBulto.new(user: @user).guardar!(paquete_ids: cajas.map(&:id), volumenes: volumenes)
  end

  # El QR de la etiqueta de medición: el código de la primera caja de la tanda.
  def qr(primera) = "MED #{primera.reload.tracking} 3.00 10x10x10"

  def auditoria(sesiones = []) = AuditoriaDeTanda.new(hoja: @hoja, sesiones: sesiones)

  # ── El volumen ─────────────────────────────────────────────────────────

  test "un QR de volumen trae la tanda entera: todos sus volúmenes y todas sus cajas" do
    cajas = 3.times.map { caja }
    uno, dos = medir(cajas, { peso: "2" }, { peso: "5" })

    r = auditoria.volumen(qr(cajas.first))

    assert_equal :ok, r.tipo
    assert_equal uno.sesion, r.sesion
    assert_equal [ uno, dos ], r.bultos
    assert_equal cajas.map(&:id).sort, r.cajas.map(&:id).sort
    assert_match(/2 volúmenes · 3 cajas/, r.mensaje)
  end

  # Después de medir de nuevo (C30-11): la etiqueta vieja sigue resolviendo a
  # la tanda de hoy. Si su «n de m» no es el de hoy, el papel está viejo.
  test "una etiqueta de una medición anterior avisa y carga la tanda de hoy" do
    cajas = 2.times.map { caja }
    medir(cajas, { peso: "2" }, { peso: "5" })

    al_dia = auditoria.volumen("#{qr(cajas.first)} 2de2")
    assert_equal :ok, al_dia.tipo
    assert_nil al_dia.aviso

    vieja = auditoria.volumen("#{qr(cajas.first)} 2de3")
    assert_equal :ok, vieja.tipo, "la tanda de hoy se carga igual"
    assert_equal 2, vieja.bultos.size
    assert_match(/medición anterior: la tanda hoy tiene 2 volúmenes — reimprimí/, vieja.aviso)

    sin_sufijo = auditoria.volumen(qr(cajas.first))
    assert_match(/medición anterior/, sin_sufijo.aviso, "sin «n de m» era de un solo volumen")
  end

  test "lo que no empieza con MED no es un volumen, aunque sea la etiqueta de la misma caja" do
    cajas = [ caja ]
    medir(cajas, { peso: "2" })

    assert_equal :no_es_volumen, auditoria.volumen(cajas.first.tracking).tipo
  end

  test "un QR que no resuelve a ninguna caja" do
    assert_equal :no_encontrado, auditoria.volumen("MED NOEXISTE123 1.00").tipo
  end

  test "una caja sin medir: medila primero" do
    sin_medir = caja
    r = auditoria.volumen("MED #{sin_medir.tracking} 1.00")

    assert_equal :sin_medir, r.tipo
    assert_match(/medila primero/, r.mensaje)
  end

  test "ya está en una pre-factura: se dice cuál, para abrirla" do
    cajas = [ caja ]
    medir(cajas, { peso: "2" })
    pf = pre_facturas(:borrador_juan)
    cajas.first.update_columns(pre_factura_id: pf.id)

    r = auditoria.volumen(qr(cajas.first))

    assert_equal :ya_prefacturada, r.tipo
    assert_equal pf, r.pre_factura
  end

  test "un grupo que todavía no está completo no se pre-factura" do
    cajas = 2.times.map { caja }
    medir(cajas, { peso: "2" })
    cajas.last.update_columns(medido_at: nil)

    assert_equal :grupo_incompleto, auditoria.volumen(qr(cajas.first)).tipo
  end

  test "fuera de la hoja, por servicio o por manifiesto (RP-85: por ahora se rechaza)" do
    cem = [ caja(tipo_envio: tipo_envios(:cem)) ]
    medir(cem, { peso: "2" })
    assert_equal :fuera_de_la_hoja, auditoria.volumen(qr(cem.first)).tipo

    otro = [ caja(manifiesto: manifiestos(:creado)) ]
    medir(otro, { peso: "2" })
    assert_equal :fuera_de_la_hoja, auditoria.volumen(qr(otro.first)).tipo
  end

  test "con una caja prepagada en Miami: caso complejo, por Pre-Facturas › A mano (excepciones)" do
    cajas = [ caja, caja(prepagado_miami: true, prepagado_miami_metodo: "efectivo") ]
    medir(cajas, { peso: "4" })

    r = auditoria.volumen(qr(cajas.first))
    assert_equal :prepagada, r.tipo
    assert_match(/Pre-Facturas › A mano \(excepciones\)/, r.mensaje)
  end

  test "la misma tanda dos veces" do
    cajas = [ caja ]
    bulto, = medir(cajas, { peso: "2" })

    assert_equal :repetido, auditoria([ bulto.sesion ]).volumen(qr(cajas.first)).tipo
  end

  test "otra tanda de otro cliente no va en la misma pre-factura" do
    mias = [ caja ]
    mia, = medir(mias, { peso: "2" })
    ajenas = [ caja(cliente: clientes(:maria)) ]
    medir(ajenas, { peso: "2" })

    r = auditoria([ mia.sesion ]).volumen(qr(ajenas.first))
    assert_equal :no_va_junto, r.tipo
  end

  test "otra tanda del mismo cliente y servicio sí" do
    uno = [ caja ]
    a, = medir(uno, { peso: "2" })
    dos = [ caja ]
    medir(dos, { peso: "3" })

    assert_equal :ok, auditoria([ a.sesion ]).volumen(qr(dos.first)).tipo
  end

  # ── Las cajas ──────────────────────────────────────────────────────────

  test "la etiqueta de Miami de una caja de la tanda: pertenece; dos veces: ya escaneada" do
    cajas = 2.times.map { caja }
    bulto, = medir(cajas, { peso: "2" })
    a = auditoria([ bulto.sesion ])

    assert_equal :pertenece, a.caja(cajas.last.tracking).tipo
    assert_equal :ya_escaneada, a.caja(cajas.last.tracking, escaneadas: [ cajas.last.id ]).tipo
  end

  test "una caja de otro cliente no corresponde, y lo dice" do
    cajas = [ caja ]
    bulto, = medir(cajas, { peso: "2" })
    ajena = caja(cliente: clientes(:maria))

    r = auditoria([ bulto.sesion ]).caja(ajena.tracking)
    assert_equal :no_corresponde, r.tipo
    assert_match(/no corresponde/, r.mensaje)
  end

  test "una caja antes de cualquier volumen: primero el volumen" do
    assert_equal :sin_volumen, auditoria.caja(caja.tracking).tipo
  end
end
