require "test_helper"

# PR-P.2 · Disponible programado (`C30-16`, PR-D1 §A, `A7-16`).
#
# La pre-factura se termina en la tarde y el cliente se entera a la hora de la
# fecha de trabajo —7:30 por defecto—. Hasta esa hora la carga espera en
# aduana; a esa hora pasa a disponible y sale el correo. Una vez.
class HacerDisponiblesTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper

  setup do
    Tarifa.delete_all
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD")
    @cliente = clientes(:juan)
    @siete_y_media = Time.zone.local(2026, 10, 10, 7, 30)
  end

  def caja(estado: "en_aduana", **extra)
    p = Paquete.create!(tracking: "1ZDISP#{SecureRandom.hex(5).upcase}", cliente: @cliente,
                        tipo_envio: tipo_envios(:cer), sucursal: sucursales(:zeron_sps),
                        sucursal_recepcion: sucursales(:miami), estado: "en_aduana",
                        descripcion: "Zapatos", peso: 10, **extra)
    p.update!(estado: estado) if estado != "en_aduana"
    p
  end

  def programada(cajas, a: @siete_y_media)
    pf = PreFactura.build_from_paquetes(@cliente, cajas.map(&:id), user: users(:admin))
    pf.notificar_at = a
    pf.save!
    pf
  end

  def barrer(ahora = @siete_y_media + 1.minute) = HacerDisponibles.call(ahora: ahora)

  # ── El camino feliz, una vez ────────────────────────────────────────────

  test "a la hora: confirma, pasa la carga a disponible, avisa y sella; el segundo barrido no hace nada" do
    cajas = [ caja, caja ]
    pf = programada(cajas)

    assert_enqueued_emails 1 do
      assert_equal 1, barrer
    end

    assert_equal "pendiente", pf.reload.estado
    assert_equal [ "disponible_entrega" ] * 2, cajas.map { |c| c.reload.estado }
    assert_equal @siete_y_media + 1.minute, pf.notificado_at
    assert cajas.all? { |c| c.reload.llegada_notificada_at.present? }
    assert_nil pf.notificacion_error

    assert_no_enqueued_emails do
      assert_equal 0, barrer
      assert_equal 0, barrer(@siete_y_media + 2.hours)
    end
  end

  test "antes de la hora no pasa nada, y la carga sigue en aduana" do
    cajas = [ caja ]
    pf = programada(cajas)

    assert_no_enqueued_emails { assert_equal 0, barrer(@siete_y_media - 1.minute) }
    assert_equal "creado", pf.reload.estado
    assert_equal "en_aduana", cajas.first.reload.estado
  end

  test "si le corren la hora para mañana antes de que salga, no sale hoy" do
    pf = programada([ caja ])
    pf.update!(notificar_at: @siete_y_media + 1.day)

    assert_no_enqueued_emails { assert_equal 0, barrer }
    assert_nil pf.reload.notificado_at
  end

  test "editada después del aviso, no se vuelve a avisar" do
    pf = programada([ caja ])
    barrer
    pf.update!(notas: "se corrigió algo", notificar_at: @siete_y_media + 2.minutes)

    assert_no_enqueued_emails { assert_equal 0, barrer(@siete_y_media + 1.hour) }
  end

  test "facturada antes de la hora: la carga igual sale de aduana a la hora" do
    cajas = [ caja, caja ]
    pf = programada(cajas)
    pf.facturar!
    assert_equal [ "en_aduana" ] * 2, cajas.map { |c| c.reload.estado }

    assert_enqueued_emails(1) { barrer }
    assert_equal "facturado", pf.reload.estado
    assert_equal [ "disponible_entrega" ] * 2, cajas.map { |c| c.reload.estado }
  end

  test "lo que estaba consolidando también sale disponible" do
    cajas = [ caja(estado: "consolidando_honduras") ]
    pf = PreFactura.new(cliente: @cliente, notificar_at: @siete_y_media)
    pf.pre_factura_items.build(paquete: cajas.first, concepto: "Flete", subtotal: 10, origen: "manual")
    pf.save!

    barrer
    assert_equal "disponible_entrega", cajas.first.reload.estado
  end

  # ── Una que falla no frena a las demás ──────────────────────────────────

  test "una tarea que bloquea frena SU aviso, queda el porqué, y las otras salen" do
    trabada = caja
    Tarea.create!(titulo: "Falta la factura comercial", paquete: trabada, cliente: @cliente,
                  bloquea_avance: true, estado: "pendiente", origen: "manual")
    mala = programada([ trabada ])
    buena = programada([ caja ])

    assert_enqueued_emails(1) { assert_equal 1, barrer }

    assert_nil mala.reload.notificado_at
    assert_includes mala.notificacion_error, "tarea pendiente"
    assert_equal "creado", mala.estado, "nada a medias: la transacción se deshizo"
    assert_equal "en_aduana", trabada.reload.estado
    assert buena.reload.notificado_at.present?

    # Cerrada la tarea, el barrido siguiente la saca.
    Tarea.where(paquete: trabada).update_all(estado: "realizada")
    assert_enqueued_emails(1) { assert_equal 1, barrer(@siete_y_media + 5.minutes) }
    assert_equal "disponible_entrega", trabada.reload.estado
  end

  test "un cliente sin correo: la carga sale disponible igual y queda dicho que no se avisó" do
    @cliente.update_columns(email: nil)
    cajas = [ caja ]
    pf = programada(cajas)

    assert_no_enqueued_emails { assert_equal 1, barrer }
    assert_equal "disponible_entrega", cajas.first.reload.estado
    assert pf.reload.notificado_at.present?
    assert_includes pf.notificacion_error, "no tiene correo"
  end

  test "una anulada no se avisa" do
    pf = programada([ caja ])
    pf.anular!

    assert_no_enqueued_emails { assert_equal 0, barrer }
  end

  test "el job corre el barrido, y está en recurring.yml cada minuto" do
    pf = programada([ caja ], a: 1.minute.ago)

    assert_enqueued_emails(1) { HacerDisponiblesProgramadasJob.perform_now }
    assert pf.reload.notificado_at.present?

    tarea = YAML.load_file(Rails.root.join("config/recurring.yml")).dig("production", "hacer_disponibles_programadas")
    assert_equal "HacerDisponiblesProgramadasJob", tarea["class"]
    assert_equal "every minute", tarea["schedule"]
  end

  # ── La hora, sin segundos ───────────────────────────────────────────────

  test "notificar_at se guarda sin segundos, y fecha_trabajo es su día" do
    pf = programada([ caja ], a: Time.zone.local(2026, 10, 12, 7, 30, 42))

    assert_equal 0, pf.reload.notificar_at.sec
    assert_equal Date.new(2026, 10, 12), pf.fecha_trabajo
  end

  test "la hora de disponible es 7:30 si nadie dice otra, y se cambia por Configuracion" do
    assert_equal "07:30", PreFactura.hora_disponible
    assert_equal Time.zone.local(2026, 10, 12, 7, 30), PreFactura.notificar_at_para(Date.new(2026, 10, 12))

    Configuracion.set("prefactura_hora_disponible", "08:15")
    assert_equal Time.zone.local(2026, 10, 12, 8, 15), PreFactura.notificar_at_para(Date.new(2026, 10, 12))

    Configuracion.set("prefactura_hora_disponible", "a las ocho")
    assert_equal "07:30", PreFactura.hora_disponible, "un valor que no es una hora no rompe el barrido"
  end

  # ── El correo ───────────────────────────────────────────────────────────

  test "el correo dice número, valor, tipo de envío, sucursal y la hora sin segundos" do
    pf = programada([ caja ], a: Time.zone.local(2026, 10, 10, 7, 30, 59))
    correo = PreFacturaMailer.disponible(pf.reload)

    assert_equal [ @cliente.email ], correo.to
    assert_includes correo.subject, pf.numero
    assert_includes correo.subject, sucursales(:zeron_sps).nombre
    [ correo.html_part.body.to_s, correo.text_part.body.to_s ].each do |cuerpo|
      assert_includes cuerpo, "su pedido número"
      assert_includes cuerpo, pf.numero
      assert_includes cuerpo, ActiveSupport::NumberHelper.number_to_delimited(format("%.2f", pf.total))
      assert_includes cuerpo, tipo_envios(:cer).nombre
      assert_includes cuerpo, sucursales(:zeron_sps).nombre
      assert_includes cuerpo, "a las 07:30"
      assert_no_match(/\d{2}:\d{2}:\d{2}/, cuerpo, "la hora va sin segundos (C30-08)")
    end
  end

  test "sin sucursal en la caja, el correo nombra la de retiro del cliente" do
    @cliente.update_columns(sucursal_retiro_id: sucursales(:humuya_tgu).id)
    pf = programada([ caja(sucursal: nil) ])

    assert_includes PreFacturaMailer.disponible(pf.reload).text_part.body.to_s, sucursales(:humuya_tgu).nombre
  end

  # ── Anular ──────────────────────────────────────────────────────────────

  test "anular devuelve a aduana lo que estaba consolidando, y lo demás se queda donde está" do
    consolidando = caja(estado: "consolidando_honduras")
    disponible = caja(estado: "disponible_entrega")
    pf = PreFactura.new(cliente: @cliente)
    [ consolidando, disponible ].each do |c|
      pf.pre_factura_items.build(paquete: c, concepto: "Flete", subtotal: 10, origen: "manual")
    end
    pf.save!

    assert pf.anular!
    assert_equal "en_aduana", consolidando.reload.estado
    assert_equal "disponible_entrega", disponible.reload.estado
    assert_equal 2, Paquete.facturables.where(id: [ consolidando.id, disponible.id ]).count
  end
end
