require "test_helper"

# C34-05 · `RP-111` · El consolidado que se midió en partes y ya se guardó con
# F8: cuando llega lo que faltaba, «medir de nuevo todo junto» reemplaza lo
# viejo, y la pre-factura queda con **un** peso.
#
# Lo que le pasó al equipo: *"primero puse dos trackings y los mandé a
# prefactura. Le puse consolidando… volví a escanear los otros trackings que
# tenía y me los agregó como un nuevo peso, no lo sumó al anterior… te sacó
# tres volúmenes"*. Yusef: *"si el cliente está consolidando, es actualización
# de pesos"*. Jorge, el 2026-10-31: medir de nuevo todo junto, y lo nuevo
# reemplaza.
class MedirDeNuevoDespuesDeF8Test < ActiveSupport::TestCase
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
    @pa = PreAlerta.create!(numero_documento: "PA-RM#{SecureRandom.hex(3).upcase}", cliente: @cliente,
                            tipo_envio: @cer, consolidado: true, con_reempaque: true, estado: "pre_alerta",
                            titulo: "Consolidado", creado_por_tipo: "usuario", creado_por_id: users(:admin).id)
    %w[1ZRMCONS0000001 1ZRMCONS0000002 1ZRMCONS0000003].each do |t|
      @pa.pre_alerta_paquetes.create!(tracking: t, descripcion: "Bulto", fecha: Date.current)
    end
    @una, @dos, @tres = @pa.pre_alerta_paquetes.order(:id).map(&:paquete)
  end

  def llego(paquete)
    paquete.update!(estado: "recibido_miami", sucursal_recepcion: sucursales(:miami))
    paquete.reload.update!(estado: "en_aduana", manifiesto: @manifiesto, peso: 2)
    paquete.reload
  end

  def medir(cajas, peso, reemplaza: [])
    MedirBulto.new(user: @user).guardar!(paquete_ids: cajas.map(&:id), volumenes: [ { peso: peso } ],
                                         reemplaza_sesiones: reemplaza)
  end

  def guardar(sesiones, escaneadas, modo: :avisar, pre_factura_id: nil)
    GuardarPreFacturaAuditada.new(hoja: @hoja, sesiones: sesiones, escaneadas: escaneadas, user: @user,
                                  modo: modo, pre_factura_id: pre_factura_id).call
  end

  test "F8 con dos de tres; llega la tercera; medir de nuevo todo junto deja un solo peso" do
    llego(@una)
    llego(@dos)
    # El cliente tiene recolecta en el primero: su línea automática no puede salir dos veces.
    @una.update_columns(recolecta_solicitada: true, recolecta_monto: 5)
    vieja, = medir([ @una, @dos ], "6")
    f8 = guardar([ vieja.sesion ], [ @una.id, @dos.id ], modo: :consolidar)
    assert_equal "consolidando_honduras", @una.reload.estado

    llego(@tres)
    nuevo, = medir([ @una, @dos, @tres ], "9", reemplaza: [ vieja.sesion ])

    assert f8.reload.anulado?, "la consolidando se anula: lo nuevo va en otra"
    assert_includes f8.notas, "medir de nuevo todo junto"
    assert_equal [ nil, nil, nil ], [ @una, @dos, @tres ].map { |c| c.reload.pre_factura_id }
    assert_equal %w[en_aduana en_aduana en_aduana], [ @una, @dos, @tres ].map(&:estado)
    assert_equal [ nuevo.sesion ], [ @una, @dos, @tres ].map(&:medicion_sesion).uniq

    pf = guardar([ nuevo.sesion ], [ @una.id, @dos.id, @tres.id ])

    lineas = pf.pre_factura_items.reload
    assert_equal 1, lineas.count { |i| i.origen == "volumen" }, "un peso, no dos"
    assert_equal 9.0, lineas.find { |i| i.origen == "volumen" }.bulto.peso.to_f
    assert_equal 1, lineas.count { |i| i.origen == "auto_recolecta" }, "la recolecta una sola vez"
    assert pf.notificar_at.present?, "completo: F9 sin preguntar"
  end

  test "las tres tandas de «medirlo solo» se juntan en una" do
    [ @una, @dos, @tres ].each { |c| llego(c) }
    supervisor = users(:supervisor_prefactura)
    supervisor.update!(pin: "1234")
    pin = { supervisor_id: supervisor.id, pin: "1234", motivo: "en partes" }
    tandas = [ @una, @dos ].map do |c|
      MedirBulto.new(user: @user).guardar!(paquete_ids: [ c.id ], volumenes: [ { peso: "2" } ], autorizacion: pin).first
    end
    tercera = MedirBulto.new(user: @user).guardar!(paquete_ids: [ @tres.id ], volumenes: [ { peso: "2" } ]).first

    nuevo, = medir([ @una, @dos, @tres ], "5", reemplaza: (tandas + [ tercera ]).map(&:sesion))

    assert_equal 1, Bulto.where(sesion: [ @una, @dos, @tres ].map { |c| c.reload.medicion_sesion }.uniq).count
    assert_equal nuevo.sesion, @tres.medicion_sesion
  end

  test "una consolidando con otra tanda que no se trae no se anula" do
    llego(@una)
    llego(@dos)
    supervisor = users(:supervisor_prefactura)
    supervisor.update!(pin: "1234")
    pin = { supervisor_id: supervisor.id, pin: "1234", motivo: "en partes" }
    a = MedirBulto.new(user: @user).guardar!(paquete_ids: [ @una.id ], volumenes: [ { peso: "2" } ], autorizacion: pin).first
    b = MedirBulto.new(user: @user).guardar!(paquete_ids: [ @dos.id ], volumenes: [ { peso: "2" } ]).first
    f8 = guardar([ a.sesion, b.sesion ], [ @una.id, @dos.id ], modo: :consolidar)

    e = assert_raises(MedirBulto::NoSePuede) { medir([ @una ], "3", reemplaza: [ a.sesion ]) }
    assert_match(/tiene más tandas/, e.message)
    assert_not f8.reload.anulado?
  end

  test "lo ya avisado sigue frenando" do
    llego(@una)
    llego(@dos)
    llego(@tres)
    vieja, = medir([ @una, @dos, @tres ], "6")
    pf = guardar([ vieja.sesion ], [ @una.id, @dos.id, @tres.id ])
    pf.update_columns(notificado_at: Time.current)

    e = assert_raises(MedirBulto::NoSePuede) { medir([ @una, @dos, @tres ], "9", reemplaza: [ vieja.sesion ]) }
    assert_match(/Anulá la pre-factura primero/, e.message)
  end
end
