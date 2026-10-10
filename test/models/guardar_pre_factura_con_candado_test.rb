require "test_helper"

# PR-P.8 · Dos F9 sobre la misma tanda, de verdad a la vez.
#
# QA lo hizo con dos pestañas: las dos pasaban la validación y la segunda
# moría en `RecordNotUnique` sobre `pre_facturas.numero` —un 500 sin JSON—, y
# que quedara una sola pre-factura era suerte. Acá van dos hilos con dos
# conexiones, como dos pedidos: el primero se frena **adentro** de la
# transacción, con las cajas ya validadas, y el segundo arranca en ese
# momento. Con el candado, el segundo espera y después ve las cajas tomadas.
#
# Sin transacción de test: dos conexiones no ven lo que la otra no confirmó, y
# eso es justo lo que se prueba. Lo que se crea se borra a mano al final.
class GuardarPreFacturaConCandadoTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @user = users(:supervisor_prefactura)
    @cliente = clientes(:juan)
    @cer = tipo_envios(:cer)
    @manifiesto = manifiestos(:enviado)
    @manifiesto.update_columns(estado: "en_aduana")
    @hoja = HojaDePreparacion.new(modo: "nuevas", tipo_envio_ids: [ @cer.id ], manifiesto_ids: [ @manifiesto.id ],
                                  disponible_en: 1.day.from_now.change(hour: 13, min: 0))
    @cajas = 3.times.map do
      Paquete.create!(tracking: "1ZCAND#{SecureRandom.hex(5).upcase}", cliente: @cliente, tipo_envio: @cer,
                      sucursal_recepcion: sucursales(:miami), manifiesto: @manifiesto,
                      estado: "en_aduana", descripcion: "Zapatos", peso: 2)
    end
    @bulto, = MedirBulto.new(user: @user).guardar!(paquete_ids: @cajas.map(&:id), volumenes: [ { peso: "6" } ])
  end

  teardown do
    pfs = PreFactura.joins(:pre_factura_items).where(pre_factura_items: { paquete_id: @cajas.map(&:id) }).distinct.pluck(:id)
    Paquete.where(id: @cajas.map(&:id)).update_all(pre_factura_id: nil)
    PreFacturaItem.where(pre_factura_id: pfs).delete_all
    PreFactura.where(id: pfs).delete_all
    Bulto.where(sesion: @bulto.sesion).delete_all
    Paquete.where(id: @cajas.map(&:id)).delete_all
  end

  def guardar
    GuardarPreFacturaAuditada.new(hoja: @hoja, sesiones: [ @bulto.sesion ], escaneadas: @cajas.map(&:id), user: @user).call
  end

  # Corre en su propia conexión y devuelve lo que pasó, sin tirar: el hilo no
  # tiene que morir para que el test vea el error.
  def en_su_conexion
    ActiveRecord::Base.connection_pool.with_connection do
      { pre_factura: yield }
    rescue StandardError => e
      { error: e }
    end
  end

  test "dos F9 a la vez: una pre-factura, y el segundo recibe el rechazo de siempre, no un RecordNotUnique" do
    adentro = Queue.new
    seguir = Queue.new
    original = ArmarPreFacturaPorVolumen.method(:call)
    original_sin_atar = ArmarPreFacturaPorVolumen.singleton_class.instance_method(:call)
    # El primero se frena justo después de validar, con las cajas en la mano.
    pausar = lambda do |**argumentos|
      if Thread.current[:primero]
        adentro << true
        seguir.pop
      end
      original.call(**argumentos)
    end

    ArmarPreFacturaPorVolumen.singleton_class.define_method(:call, pausar)
    resultados = begin
      primero = Thread.new do
        Thread.current[:primero] = true
        en_su_conexion { guardar }
      end
      adentro.pop

      segundo = Thread.new { en_su_conexion { guardar } }
      # El segundo no termina mientras el primero tiene las cajas: espera el
      # candado. Sin él, validaba contra cajas todavía libres y seguía.
      assert_nil segundo.join(1.5), "el segundo F9 no esperó al primero"

      seguir << true
      [ primero.value, segundo.join(10)&.value ]
    ensure
      seguir << true
      ArmarPreFacturaPorVolumen.singleton_class.define_method(:call, original_sin_atar)
    end

    uno, dos = resultados
    assert uno[:pre_factura]&.persisted?, "el primero no guardó: #{uno[:error]&.message}"
    assert dos, "el segundo nunca terminó"
    assert_kind_of GuardarPreFacturaAuditada::NoSePuede, dos[:error], "el segundo tenía que rechazarse: #{dos.inspect}"
    assert_includes dos[:error].message, uno[:pre_factura].numero, "el rechazo nombra la pre-factura que se llevó las cajas"

    assert_equal 1, PreFactura.joins(:pre_factura_items).where(pre_factura_items: { paquete_id: @cajas.map(&:id) })
                              .distinct.count, "una sola pre-factura cobra estas cajas"
    assert_equal [ uno[:pre_factura].id ] * 3, @cajas.map { |c| c.reload.pre_factura_id }
  end

  test "si el número choca con otro guardado simultáneo, se reintenta y guarda" do
    choques = 0
    numerar = PreFactura.instance_method(:save!)
    PreFactura.class_eval do
      alias_method :__save_sin_choque!, :save!
    end
    PreFactura.define_method(:save!) do |*args, **opciones, &bloque|
      if choques.zero?
        choques += 1
        raise ActiveRecord::RecordNotUnique, "PG::UniqueViolation: duplicate key value violates unique constraint " \
                                             "\"index_pre_facturas_on_numero\""
      end
      __save_sin_choque!(*args, **opciones, &bloque)
    end

    pf = guardar

    assert_equal 1, choques
    assert pf.persisted?
    assert_equal [ pf.id ] * 3, @cajas.map { |c| c.reload.pre_factura_id }
  ensure
    PreFactura.define_method(:save!, numerar)
    PreFactura.send(:remove_method, :__save_sin_choque!) if PreFactura.method_defined?(:__save_sin_choque!)
  end
end
