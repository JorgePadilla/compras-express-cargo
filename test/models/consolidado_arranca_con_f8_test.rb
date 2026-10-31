require "test_helper"

# C34-07 · Lista 14 y 23 · El consolidado arranca con F8, y F9 pregunta.
#
# En la pasada del 2026-10-30 salió en pantalla «es de un grupo que todavía no
# está completo». Yusef: *"aquí no debería ser bloqueado… porque estamos
# empezando a hacerle el consolidado"*. El bloqueo iba antes de F8, así que F8
# —que reabre una consolidando— nunca podía **crear** la primera. Jorge, el
# 2026-10-31 (`RP-112`): F8 deja empezar, F9 pregunta, y el PIN de medición con
# faltantes sella «facturar lo que hay».
#
# El test viejo («un grupo que todavía no está completo no se pre-factura») no
# armaba ningún grupo: tocaba `medido_at`. Estos arman uno de verdad.
class ConsolidadoArrancaConF8Test < ActiveSupport::TestCase
  setup do
    @user = users(:supervisor_prefactura)
    @cliente = clientes(:juan)
    @cer = tipo_envios(:cer)
    @manifiesto = manifiestos(:enviado)
    @manifiesto.update_columns(estado: "en_aduana")
    Tarifa.delete_all
    Tarifa.create!(tipo_envio: @cer, precio_libra: 4.50, moneda: "USD")
    @hoja = HojaDePreparacion.new(modo: "nuevas", tipo_envio_ids: [ @cer.id ], manifiesto_ids: [ @manifiesto.id ],
                                  disponible_en: 1.day.from_now.change(hour: 13))
    @pa = PreAlerta.create!(numero_documento: "PA-F8#{SecureRandom.hex(3).upcase}", cliente: @cliente,
                            tipo_envio: @cer, consolidado: true, con_reempaque: true, estado: "pre_alerta",
                            titulo: "Consolidado de prueba", creado_por_tipo: "usuario", creado_por_id: users(:admin).id)
    %w[1ZF8CONS0000001 1ZF8CONS0000002 1ZF8CONS0000003].each do |t|
      @pa.pre_alerta_paquetes.create!(tracking: t, descripcion: "Bulto", fecha: Date.current)
    end
    @una, @dos, @tres = @pa.pre_alerta_paquetes.order(:id).map(&:paquete)
  end

  # Miami lo recibe (nace el warehouse receipt) y llega a Honduras en el manifiesto.
  def llego(paquete)
    paquete.update!(estado: "recibido_miami", sucursal_recepcion: sucursales(:miami))
    paquete.reload.update!(estado: "en_aduana", manifiesto: @manifiesto, peso: 2)
    paquete.reload
  end

  def medir(cajas, autorizacion: nil)
    MedirBulto.new(user: @user).guardar!(paquete_ids: cajas.map(&:id), volumenes: [ { peso: "4" } ],
                                         autorizacion: autorizacion)
  end

  def qr(primera) = "MED #{primera.reload.tracking} 4.00"

  def guardar(sesiones, escaneadas, modo: :avisar, confirmado: false, pre_factura_id: nil)
    GuardarPreFacturaAuditada.new(hoja: @hoja, sesiones: sesiones, escaneadas: escaneadas, user: @user,
                                  modo: modo, confirmado: confirmado, pre_factura_id: pre_factura_id).call
  end

  test "el escaneo del volumen ya no traba: dice qué falta y dónde está" do
    llego(@una)
    bulto, = medir([ @una ])

    r = AuditoriaDeTanda.new(hoja: @hoja).volumen(qr(@una))

    assert_equal :ok, r.tipo
    assert_equal bulto.sesion, r.sesion
    assert_includes r.grupo_aviso, "El consolidado #{@pa.numero_documento} no está completo"
    assert_includes r.grupo_aviso, "faltan 2 que no han llegado a Miami"
    assert_includes r.grupo_aviso, "F8 lo guarda consolidando"
    assert_nil r.aviso, "no es una etiqueta vieja: va por su propia clave"
  end

  test "lo que está acá sin medir y lo medido en otra tanda se dicen aparte: traer del estante" do
    llego(@una)
    llego(@dos)
    # @una vino y no está en la tanda de @dos: medición pide el código (C28-13).
    supervisor = users(:supervisor_prefactura)
    supervisor.update!(pin: "1234")
    otra, = medir([ @dos ], autorizacion: { supervisor_id: supervisor.id, pin: "1234", motivo: "en el estante" })
    @pa.update_columns(union_parcial_at: nil, union_parcial_por: nil) # sin el sello, para ver el aviso
    bulto, = medir([ @una ])

    aviso = AuditoriaDeTanda.new(hoja: @hoja).volumen(qr(@una)).grupo_aviso

    assert_includes aviso, "1 medido en otra tanda: traelo del estante"
    assert_includes aviso, "falta 1 que no ha llegado a Miami"
    assert_not_equal otra.sesion, bulto.sesion
  end

  test "F8 crea la pre-factura del consolidado con lo que hay" do
    llego(@una)
    bulto, = medir([ @una ])

    pf = guardar([ bulto.sesion ], [ @una.id ], modo: :consolidar)

    assert pf.consolidando_at.present?
    assert_nil pf.notificar_at
    assert_equal pf.id, @una.reload.pre_factura_id
    assert_equal "consolidando_honduras", @una.estado
  end

  test "F9 con el grupo incompleto pregunta, y con la respuesta guarda" do
    llego(@una)
    bulto, = medir([ @una ])

    e = assert_raises(GuardarPreFacturaAuditada::NecesitaConfirmacion) { guardar([ bulto.sesion ], [ @una.id ]) }
    assert_includes e.message, "faltan 2 que no han llegado a Miami"
    assert_nil @una.reload.pre_factura_id, "la pregunta no guarda nada"

    pf = guardar([ bulto.sesion ], [ @una.id ], confirmado: true)

    assert pf.notificar_at.present?
    assert_nil pf.consolidando_at
  end

  test "F9 sobre la consolidando reabierta mira también las tandas viejas" do
    llego(@una)
    vieja, = medir([ @una ])
    pf = guardar([ vieja.sesion ], [ @una.id ], modo: :consolidar)
    llego(@dos)
    nueva, = medir([ @dos ])

    assert_raises(GuardarPreFacturaAuditada::NecesitaConfirmacion) do
      guardar([ vieja.sesion, nueva.sesion ], [ @una.id, @dos.id ], pre_factura_id: pf.id)
    end

    llego(@tres)
    tercera, = medir([ @tres ])
    cerrada = guardar([ vieja.sesion, nueva.sesion, tercera.sesion ], [ @una.id, @dos.id, @tres.id ],
                      pre_factura_id: pf.id)

    assert_equal pf.id, cerrada.id, "completo: F9 avisa sin preguntar"
    assert cerrada.notificar_at.present?
  end

  test "con «facturar lo que hay» sellado, F9 no pregunta" do
    llego(@una)
    bulto, = medir([ @una ])
    @pa.update_columns(union_parcial_at: Time.current, union_parcial_por: "SP")

    assert_nil AuditoriaDeTanda.new(hoja: @hoja).volumen(qr(@una)).grupo_aviso
    assert guardar([ bulto.sesion ], [ @una.id ]).notificar_at.present?
  end

  test "lista 23 · el código de supervisor en medición sella «facturar lo que hay»" do
    supervisor = users(:supervisor_prefactura)
    supervisor.update!(pin: "1234")
    llego(@una)
    llego(@dos) # vino y no aparece: medición pide el código

    bulto, = medir([ @una ], autorizacion: { supervisor_id: supervisor.id, pin: "1234", motivo: "no aparece" })

    assert @pa.reload.union_parcial_at.present?
    assert_includes @pa.historial.to_s, "con el código de supervisor en medición"
    assert guardar([ bulto.sesion ], [ @una.id ]).notificar_at.present?, "F9 sin preguntar"
  end

  test "lo que no está medido sigue trabando" do
    llego(@una)
    otra = Paquete.create!(tracking: "1ZF8SUELTA00001", cliente: @cliente, tipo_envio: @cer,
                           sucursal_recepcion: sucursales(:miami), manifiesto: @manifiesto,
                           estado: "en_aduana", descripcion: "Zapatos", peso: 2)
    bulto, = MedirBulto.new(user: @user).guardar!(paquete_ids: [ otra.id ], volumenes: [ { peso: "2" } ])
    otra.update_columns(medido_at: nil)

    r = AuditoriaDeTanda.new(hoja: @hoja).volumen(qr(otra))

    assert_equal :sin_medir, r.tipo
    assert_not r.ok?
    assert bulto
  end
end
