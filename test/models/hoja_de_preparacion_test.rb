require "test_helper"

# PR-P.4 · C30-15 / C30-16 · La hoja de preparación: qué manifiestos ofrece y
# la fecha de trabajo.
#
# Yusef: *"solo le van a aparecer los que ya fueron recibidos"* · *"cuando ya
# entra prefactura y lo seleccionamos y lo terminamos, desaparece de los
# pendientes"* · *"el default es 7 y media"*.
class HojaDePreparacionTest < ActiveSupport::TestCase
  setup do
    @cer = tipo_envios(:cer)
    @cem = tipo_envios(:cem)
    @manifiesto = manifiestos(:enviado)   # oficial, lleva CER
    @manifiesto.update_columns(estado: "en_aduana")

    @uno = paquetes(:recibido)
    @dos = paquetes(:empacado)
    [ @uno, @dos ].each do |p|
      p.update_columns(manifiesto_id: @manifiesto.id, tipo_envio_id: @cer.id, estado: "en_aduana",
                       pre_factura_id: nil, venta_id: nil)
    end
  end

  # ── Manifiesto.para_hoja ────────────────────────────────────────────────

  test "un oficial en aduana con carga sin pre-facturar de ese servicio sale" do
    assert_includes Manifiesto.para_hoja([ @cer.id ]), @manifiesto
  end

  test "también uno ya recibido entero" do
    @manifiesto.update_columns(estado: "recibido")
    assert_includes Manifiesto.para_hoja([ @cer.id ]), @manifiesto
  end

  test "de otro servicio no sale" do
    assert_not_includes Manifiesto.para_hoja([ @cem.id ]), @manifiesto
  end

  test "con dos servicios elegidos, alcanza con uno" do
    assert_includes Manifiesto.para_hoja([ @cem.id, @cer.id ]), @manifiesto
  end

  test "sin servicios no ofrece nada" do
    assert_empty Manifiesto.para_hoja([])
  end

  test "el que todavía viene en camino, o el que se está armando, no sale" do
    @manifiesto.update_columns(estado: "enviado")
    assert_not_includes Manifiesto.para_hoja([ @cer.id ]), @manifiesto
    @manifiesto.update_columns(estado: "creado")
    assert_not_includes Manifiesto.para_hoja([ @cer.id ]), @manifiesto
  end

  test "desaparece cuando todos sus paquetes tienen pre-factura" do
    @uno.update_columns(pre_factura_id: pre_facturas(:borrador_juan).id)
    assert_includes Manifiesto.para_hoja([ @cer.id ]), @manifiesto, "le queda uno"

    @dos.update_columns(pre_factura_id: pre_facturas(:borrador_juan).id)
    assert_not_includes Manifiesto.para_hoja([ @cer.id ]), @manifiesto
  end

  test "si falta una caja, se queda en la lista aunque lo demás esté pre-facturado" do
    # C28-14: la caja que no llegó deja su paquete en `enviado_honduras`, sin
    # pre-factura. Es carga del manifiesto que todavía no se cobró.
    @uno.update_columns(pre_factura_id: pre_facturas(:borrador_juan).id)
    @dos.update_columns(estado: "enviado_honduras")

    assert_includes Manifiesto.para_hoja([ @cer.id ]), @manifiesto
  end

  test "un paquete anulado no lo retiene" do
    @uno.update_columns(pre_factura_id: pre_facturas(:borrador_juan).id)
    @dos.update_columns(estado: "anulado")

    assert_not_includes Manifiesto.para_hoja([ @cer.id ]), @manifiesto
  end

  test "el interno nunca sale, ni en aduana ni recibido" do
    @manifiesto.update_columns(tipo: "interno", estado: "recibido")
    assert_not_includes Manifiesto.para_hoja([ @cer.id ]), @manifiesto
    @manifiesto.update_columns(estado: "en_aduana")
    assert_not_includes Manifiesto.para_hoja([ @cer.id ]), @manifiesto
  end

  # PR-P.11a · Lo que un admin sacó de Medición («perdido», «ya fue
  # entregado») nunca se va a pre-facturar escaneando: no puede dejar al
  # manifiesto en la hoja para siempre.
  test "un descartado de medición no lo retiene" do
    @uno.update_columns(pre_factura_id: pre_facturas(:borrador_juan).id)
    @dos.update_columns(medicion_descartada_at: Time.current)

    assert_not_includes Manifiesto.para_hoja([ @cer.id ]), @manifiesto
  end

  # ── PR-P.11a · «Sin manifiesto oficial» ────────────────────────────────

  test "«Sin manifiesto oficial» se ofrece solo si hay carga así, y con ella sola la hoja está lista" do
    HojaDePreparacion.carga_sin_manifiesto([ @cer.id ]).update_all(estado: "entregado") # lo que traen las fixtures
    hoja = HojaDePreparacion.new(modo: "nuevas", tipo_envio_ids: [ @cer.id ], sin_manifiesto: true)
    assert_not hoja.ofrece_sin_manifiesto?
    assert_not hoja.lista?, "elegido pero sin nada que auditar"

    @uno.update_columns(manifiesto_id: nil)
    assert hoja.ofrece_sin_manifiesto?
    assert hoja.lista?, "sin ningún manifiesto elegido"
    assert_not HojaDePreparacion.new(modo: "nuevas", tipo_envio_ids: [ @cer.id ]).lista?, "sin la casilla, no"

    interno = manifiestos(:creado)
    interno.update_columns(tipo: "interno")
    @uno.update_columns(manifiesto_id: interno.id)
    assert hoja.ofrece_sin_manifiesto?, "la que anda en un interno también"
    assert hoja.acepta_manifiesto?(@uno.reload)
    assert_not HojaDePreparacion.new(modo: "nuevas", tipo_envio_ids: [ @cer.id ]).acepta_manifiesto?(@uno)
  end

  test "la casilla va y vuelve por la sesión, y se destilda" do
    hoja = HojaDePreparacion.new(modo: "nuevas", tipo_envio_ids: [ @cer.id ]).con("sin_manifiesto" => "1")
    assert hoja.sin_manifiesto?
    assert HojaDePreparacion.desde_sesion(JSON.parse(hoja.to_sesion.to_json)).sin_manifiesto?
    assert hoja.con("modo" => "nuevas").sin_manifiesto?, "sin la clave se queda la de antes"
    assert_not hoja.con("sin_manifiesto" => "0").sin_manifiesto?
  end

  test "«editar» ofrece las que salieron de la auditoría, tengan o no manifiesto" do
    auditada = pre_facturas(:borrador_juan)
    auditada.update_columns(manifiesto_id: nil, estado: "creado", notificar_at: 1.day.from_now,
                            auditado_por_id: users(:supervisor_prefactura).id)
    a_mano = pre_facturas(:pendiente_maria)
    a_mano.update_columns(manifiesto_id: @manifiesto.id, estado: "creado", notificar_at: 1.day.from_now,
                          auditado_por_id: nil, notificado_at: nil)

    editables = HojaDePreparacion.pre_facturas_editables
    assert_includes editables, auditada, "«Sin manifiesto oficial» también se corrige"
    assert_not_includes editables, a_mano, "una hecha a mano no salió de la auditoría"
  end

  # ── La fecha de trabajo ────────────────────────────────────────────────

  test "sin la clave en Configuracion, la hora es 07:30" do
    Configuracion.where(clave: "prefactura_hora_disponible").delete_all
    assert_equal "07:30", HojaDePreparacion.hora_por_defecto

    hoja = HojaDePreparacion.new
    assert_equal Date.current, hoja.disponible_en.to_date
    assert_equal [ 7, 30, 0 ], [ hoja.disponible_en.hour, hoja.disponible_en.min, hoja.disponible_en.sec ]
  end

  # Un solo lector de la clave: `PreFactura.hora_disponible` (PR-P.2). La hoja
  # muestra lo mismo que la pre-factura va a usar para avisar.
  test "con la clave, manda la clave, leída como la lee la pre-factura" do
    Configuracion.set("prefactura_hora_disponible", "13:00")
    assert_equal "13:00", HojaDePreparacion.hora_por_defecto

    Configuracion.set("prefactura_hora_disponible", "8:00")
    assert_equal "08:00", HojaDePreparacion.hora_por_defecto, "el campo la quiere con dos dígitos"

    Configuracion.set("prefactura_hora_disponible", "siete y media")
    assert_equal "07:30", HojaDePreparacion.hora_por_defecto
  end

  test "la hoja y la pre-factura dicen la misma hora" do
    [ "13:00", "8:00", "08:00:00", "siete y media" ].each do |valor|
      Configuracion.set("prefactura_hora_disponible", valor)
      assert_equal PreFactura.notificar_at_para(Date.current), HojaDePreparacion.disponible_por_defecto, valor
    end
  end

  test "la hora que llega con segundos se guarda sin ellos" do
    hoja = HojaDePreparacion.new.con("fecha" => "2026-10-12", "hora" => "14:05:33")

    assert_equal Time.zone.local(2026, 10, 12, 14, 5, 0), hoja.disponible_en
  end

  test "una fecha que no se entiende deja la que estaba" do
    antes = HojaDePreparacion.new.con("fecha" => "2026-10-12", "hora" => "14:05")
    despues = antes.con("fecha" => "12/10/2026x", "hora" => "99:99")

    assert_equal antes.disponible_en, despues.disponible_en
  end

  test "ida y vuelta por la sesión" do
    hoja = HojaDePreparacion.new(modo: "nuevas", tipo_envio_ids: [ @cer.id.to_s, "" ],
                                 manifiesto_ids: [ @manifiesto.id ],
                                 disponible_en: Time.zone.local(2026, 10, 12, 14, 0))
    vuelta = HojaDePreparacion.desde_sesion(JSON.parse(hoja.to_sesion.to_json))

    assert_equal [ @cer.id ], vuelta.tipo_envio_ids
    assert_equal [ @manifiesto.id ], vuelta.manifiesto_ids
    assert_equal hoja.disponible_en, vuelta.disponible_en
    assert vuelta.lista?
  end

  test "un modo que no existe cae en «nuevas»" do
    assert HojaDePreparacion.new(modo: "borrar").nuevas?
  end

  test "«editar» ofrece los manifiestos con pre-facturas sin avisar" do
    pf = pre_facturas(:borrador_juan)
    # PR-P.7: las que salieron de la auditoría — programadas o consolidando.
    # PR-P.11a: «salió de la auditoría» es `auditado_por_id`, que F9 escribe.
    pf.update_columns(manifiesto_id: @manifiesto.id, estado: "creado", notificar_at: 1.day.from_now,
                      auditado_por_id: users(:supervisor_prefactura).id)

    hoja = HojaDePreparacion.new(modo: "editar")
    assert_includes hoja.manifiestos_ofrecidos, @manifiesto
    assert_includes HojaDePreparacion.pre_facturas_editables, pf

    pf.update_columns(estado: "facturado")
    assert_not_includes HojaDePreparacion.new(modo: "editar").manifiestos_ofrecidos, @manifiesto
  end
end
