require "test_helper"
require "fugit"

# C33-03 · El resumen de las 6 de la tarde. Yusef, 2026-10-24: *"que agarre
# todos los tracking, un solo correo… por cliente, al cliente"*.
class ResumenDeEnviadosTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper

  setup do
    @juan = clientes(:juan)
    @hoy = Time.zone.local(2026, 10, 26, 18, 0)
    ActionMailer::Base.deliveries.clear
  end

  def salido(cliente: @juan, tipo: tipo_envios(:cer), estado: "enviado_honduras", **extra)
    p = Paquete.create!(tracking: "1ZSAL#{SecureRandom.hex(5).upcase}", cliente: cliente, tipo_envio: tipo,
                        sucursal_recepcion: sucursales(:miami), estado: "recibido_miami",
                        descripcion: "Zapatos", peso: 3, **extra)
    p.update_columns(estado: estado, fecha_enviado: @hoy - 3.hours) unless estado == "recibido_miami"
    p
  end

  def resumen
    perform_enqueued_jobs { ResumenDeEnviados.call(ahora: @hoy) }
  end

  test "un solo correo por cliente, con los tipos de envio agrupados" do
    salido(tipo: tipo_envios(:cer))
    salido(tipo: tipo_envios(:cer))
    salido(tipo: tipo_envios(:cem), fecha_posible_entrega: Date.new(2026, 11, 3))

    resultado = resumen

    correo = ActionMailer::Base.deliveries.sole
    assert_equal [ @juan.email ], correo.to
    assert_match "Sus 3 paquetes salieron hoy", correo.subject
    texto = correo.text_part.body.to_s
    assert_match tipo_envios(:cer).nombre, texto
    assert_match tipo_envios(:cem).nombre, texto
    assert_match FechaDeEntrega.texto(Date.new(2026, 11, 3)), texto
    assert_equal 1, resultado.avisados
  end

  test "dos clientes, dos correos" do
    otro = clientes(:maria)
    salido
    salido(cliente: otro)

    resumen

    assert_equal [ [ @juan.email ], [ otro.email ] ].sort, ActionMailer::Base.deliveries.map(&:to).sort
  end

  test "lo que ya se conto no se repite al dia siguiente" do
    salido
    resumen
    ActionMailer::Base.deliveries.clear

    perform_enqueued_jobs { ResumenDeEnviados.call(ahora: @hoy + 1.day) }

    assert_empty ActionMailer::Base.deliveries
  end

  test "lo que sigue en Miami y lo que va por el manifiesto interno no entran" do
    salido(estado: "recibido_miami")
    interno = salido(estado: "enviado_sucursal")
    interno.update_columns(fecha_enviado: nil)

    resumen

    assert_empty ActionMailer::Base.deliveries
  end

  test "el cliente sin correo se sella igual y no revienta" do
    @juan.update_columns(email: nil)
    paquete = salido

    resultado = resumen

    assert_empty ActionMailer::Base.deliveries
    assert_equal 1, resultado.sin_correo
    assert_equal @hoy, paquete.reload.envio_notificado_at
  end

  test "si deja de haber salido, se olvida el aviso y vuelve a contarse" do
    paquete = salido
    resumen
    assert paquete.reload.envio_notificado_at

    paquete.update!(fecha_enviado: nil)

    assert_nil paquete.reload.envio_notificado_at
  end

  test "el job corre todos los dias a las 6 de la tarde de Honduras" do
    tarea = YAML.load_file(Rails.root.join("config/recurring.yml"))["production"]["resumen_de_enviados"]
    # Con el reloj del proceso en UTC, como el worker de Render: sin la zona en
    # el schedule, fugit daría las 18:00 UTC.
    proxima = con_tz("UTC") { Fugit.parse(tarea["schedule"], multi: :fail).next_time(Time.utc(2026, 10, 26, 12)).to_t }

    assert_equal "ResumenDeEnviadosJob", tarea["class"]
    assert SolidQueue::RecurringTask.from_configuration("resumen_de_enviados", **tarea.symbolize_keys).valid?
    assert_equal [ 18, 0 ], proxima.in_time_zone("America/Tegucigalpa").then { |t| [ t.hour, t.min ] }
  end

  private

  def con_tz(zona)
    antes = ENV["TZ"]
    ENV["TZ"] = zona
    yield
  ensure
    ENV["TZ"] = antes
  end
end
