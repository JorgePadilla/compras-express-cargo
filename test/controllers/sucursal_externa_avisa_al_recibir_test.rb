require "test_helper"

# C34-08 · C33-04 · La sucursal que no es San Pedro: siempre F9, y **avisa
# quien recibe allá**, a la hora que pone.
#
#   > "Si es de Tegus, ustedes ya no tienen que guardar F8… cuando el manifiesto
#   >  llega a Tegus y él confirma que ya lo recibió, el sistema le va a
#   >  notificar." · "No va a notificar si es de una sucursal y no ha llegado a
#   >  la sucursal. Alexis escanea esta hoja y eso lo activa."
#   > "Imagínense, llegan 200 paquetes a Alexis… recibir carga interna,
#   >  manifiesto, ¿a qué hora es lo notificado? Tal hora."
#
# Hasta acá el F9 le mandaba el correo al cliente de Tegucigalpa con la carga
# todavía en San Pedro, y sellaba `llegada_notificada_at`: la recepción en
# Tegucigalpa ya no le avisaba nunca.
class SucursalExternaAvisaAlRecibirTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    Tarifa.delete_all
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD")
    @cliente = clientes(:juan)
    @sps = sucursales(:zeron_sps)
    @tgu = sucursales(:humuya_tgu)
    @hora = Time.zone.local(2026, 10, 10, 7, 30)
  end

  # Llegó a San Pedro en el oficial, y retira en Tegucigalpa.
  def caja(retira: @tgu, esta: @sps)
    Paquete.create!(tracking: "1ZEXT#{SecureRandom.hex(5).upcase}", cliente: @cliente,
                    tipo_envio: tipo_envios(:cer), sucursal: retira, sucursal_actual: esta,
                    sucursal_recepcion: sucursales(:miami), estado: "en_aduana",
                    descripcion: "Zapatos", peso: 10)
  end

  def programada(cajas)
    pf = PreFactura.build_from_paquetes(@cliente, cajas.map(&:id), user: users(:admin))
    pf.notificar_at = @hora
    pf.save!
    pf
  end

  def interno_con(cajas)
    m = Manifiesto.create!(tipo: "interno", estado: "enviado", sucursal_origen: @sps, sucursal_entrega: @tgu,
                           tipo_envios: [ tipo_envios(:cer) ])
    cajas.each { |c| c.reload.update!(estado: "enviado_sucursal", manifiesto: m, sucursal_destino: @tgu) }
    m
  end

  def ingresar
    post session_url, params: { email_address: users(:supervisor_prefactura).email_address, password: "password123" }
  end

  def escanear(m, caja)
    post escanear_recepcion_carga_url(m), params: { codigo: caja.tracking }
  end

  test "F9 de un cliente de Tegucigalpa: disponible para el interno, sin correo, esperando la sucursal" do
    cajas = [ caja, caja ]
    pf = programada(cajas)

    assert_no_enqueued_emails { HacerDisponibles.call(ahora: @hora + 1.minute) }

    pf.reload
    assert_nil pf.notificado_at
    assert pf.espera_llegada_at.present?
    assert_equal :espera_sucursal, pf.estado_del_aviso
    assert_equal %w[disponible_entrega disponible_entrega], cajas.map { |c| c.reload.estado }
    assert cajas.all? { |c| c.llegada_notificada_at.nil? }, "si se sella acá, la recepción allá no avisa nunca"
    assert_equal 0, HacerDisponibles.call(ahora: @hora + 2.minutes), "el barrido no la vuelve a tomar"
  end

  test "un oficial que aterrizó directo en Tegucigalpa avisa al F9, como siempre" do
    pf = programada([ caja(esta: @tgu) ])

    assert_enqueued_emails(1) { HacerDisponibles.call(ahora: @hora + 1.minute) }
    assert pf.reload.notificado_at.present?
  end

  test "San Pedro avisa al F9, como siempre" do
    pf = programada([ caja(retira: @sps) ])

    assert_enqueued_emails(1) { HacerDisponibles.call(ahora: @hora + 1.minute) }
    assert pf.reload.notificado_at.present?
  end

  test "al recibir el interno, la pre-factura que esperaba se avisa —una vez, con su correo de siempre—" do
    cajas = [ caja, caja ]
    pf = programada(cajas)
    HacerDisponibles.call(ahora: @hora + 1.minute)
    m = interno_con(cajas)
    ingresar

    cajas.each { |c| escanear(m, c) }
    assert_enqueued_email_with PreFacturaMailer, :disponible, args: [ pf ] do
      patch finalizar_recepcion_carga_url(m), params: pin_de_supervisor
    end

    assert pf.reload.notificado_at.present?
    assert cajas.all? { |c| c.reload.llegada_notificada_at.present? }
    assert_no_enqueued_emails { NotificarLlegadaASucursal.new(m).call }
  end

  test "la que llegó a medias espera al resto" do
    llega, falta = caja, caja
    pf = programada([ llega, falta ])
    HacerDisponibles.call(ahora: @hora + 1.minute)
    m = interno_con([ llega ])
    ingresar

    escanear(m, llega)
    assert_no_enqueued_emails { patch finalizar_recepcion_carga_url(m), params: pin_de_supervisor }
    assert_nil pf.reload.notificado_at
  end

  test "la hora la pone quien recibe: cerrar antes no avisa, y el barrido avisa a esa hora" do
    cajas = [ caja ]
    pf = programada(cajas)
    HacerDisponibles.call(ahora: @hora + 1.minute)
    m = interno_con(cajas)
    ingresar

    travel_to Time.zone.local(2026, 10, 11, 9, 0) do
      patch hora_aviso_recepcion_carga_url(m), params: { hora: "14:30" }
      assert_equal [ 14, 30 ], [ m.reload.aviso_llegada_at.hour, m.aviso_llegada_at.min ]

      escanear(m, cajas.first)
      assert_no_enqueued_emails { patch finalizar_recepcion_carga_url(m), params: pin_de_supervisor }
      follow_redirect!
      assert_match "El aviso a los clientes sale a las 14:30", response.body
    end

    travel_to Time.zone.local(2026, 10, 11, 14, 31) do
      assert_enqueued_emails(1) { NotificarLlegadaASucursal.barrer }
      assert pf.reload.notificado_at.present?
    end
  end
end
