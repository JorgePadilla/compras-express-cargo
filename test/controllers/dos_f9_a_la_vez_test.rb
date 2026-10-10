require "test_helper"

# PR-P.8 · Lo que vio QA, por HTTP: dos F9 sobre la misma tanda desde dos
# pestañas, de verdad a la vez. Uno guarda (200) y el otro recibe un 422 con
# JSON que la pantalla sabe leer — nunca un 500.
#
# Dos sesiones, cada una en su hilo y con su conexión. El primer guardado se
# frena adentro de la transacción, con las cajas ya validadas, y el segundo
# sale en ese momento. Sin transacción de test: lo creado se borra al final.
class DosF9ALaVezTest < ActionDispatch::IntegrationTest
  include SinTransaccionDeTest

  setup do
    @user = users(:supervisor_prefactura)
    @cer = tipo_envios(:cer)
    @manifiesto = manifiestos(:enviado)
    @manifiesto.update_columns(estado: "en_aduana")
    @cajas = 2.times.map do
      Paquete.create!(tracking: "1ZDOSF9#{SecureRandom.hex(5).upcase}", cliente: clientes(:juan), tipo_envio: @cer,
                      sucursal_recepcion: sucursales(:miami), manifiesto: @manifiesto,
                      estado: "en_aduana", descripcion: "Zapatos", peso: 2)
    end
    @bulto, = MedirBulto.new(user: @user).guardar!(paquete_ids: @cajas.map(&:id), volumenes: [ { peso: "4" } ])
  end

  teardown { borrar_lo_creado(@cajas, [ @bulto.sesion ]) }

  def pestana
    open_session do |s|
      s.post session_url, params: { email_address: @user.email_address, password: "password123" }
      s.patch hoja_de_preparacion_url, params: { hoja: { modo: "nuevas", tipo_envio_ids: [ @cer.id ],
                                                         manifiesto_ids: [ @manifiesto.id ],
                                                         fecha: 1.day.from_now.to_date.iso8601, hora: "07:30" } }
    end
  end

  def f9(sesion)
    ActiveRecord::Base.connection_pool.with_connection do
      sesion.post guardar_auditar_pre_factura_index_url,
                  params: { sesiones: [ @bulto.sesion ], escaneadas: @cajas.map(&:id) }, as: :json
      [ sesion.response.status, sesion.response.media_type, sesion.response.parsed_body ]
    end
  end

  test "dos F9 a la vez sobre la misma tanda: un 200, un 422 con JSON, y una sola pre-factura" do
    una, otra = pestana, pestana
    adentro = Queue.new
    seguir = Queue.new
    original = ArmarPreFacturaPorVolumen.method(:call)
    original_sin_atar = ArmarPreFacturaPorVolumen.singleton_class.instance_method(:call)
    ArmarPreFacturaPorVolumen.singleton_class.define_method(:call) do |**argumentos|
      if Thread.current[:primero]
        adentro << true
        seguir.pop
      end
      original.call(**argumentos)
    end

    begin
      primero = Thread.new do
        Thread.current[:primero] = true
        f9(una)
      end
      adentro.pop
      segundo = Thread.new { f9(otra) }
      assert_nil segundo.join(1.5), "el segundo F9 no esperó al primero"
      seguir << true
      respuestas = [ primero.value, segundo.join(10)&.value ]
    ensure
      seguir << true
      ArmarPreFacturaPorVolumen.singleton_class.define_method(:call, original_sin_atar)
    end

    bien, mal = respuestas
    assert_equal 200, bien[0], bien[2].inspect
    assert bien[2]["ok"]
    assert mal, "el segundo nunca contestó"
    assert_equal 422, mal[0], "el segundo F9 tenía que ser un 422, no #{mal[0]}"
    assert_equal "application/json", mal[1]
    assert_equal false, mal[2]["ok"]
    assert_includes mal[2]["mensaje"], bien[2]["numero"], "el rechazo nombra la pre-factura que se llevó las cajas"

    assert_equal 1, PreFactura.joins(:pre_factura_items).where(pre_factura_items: { paquete_id: @cajas.map(&:id) })
                              .distinct.count
  end
end
