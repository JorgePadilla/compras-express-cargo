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
  include SinTransaccionDeTest

  setup do
    @user = users(:supervisor_prefactura)
    @cliente = clientes(:juan)
    @cer = tipo_envios(:cer)
    @manifiesto = manifiestos(:enviado)
    @manifiesto.update_columns(estado: "en_aduana")
    @hoja = HojaDePreparacion.new(modo: "nuevas", tipo_envio_ids: [ @cer.id ], manifiesto_ids: [ @manifiesto.id ],
                                  disponible_en: 1.day.from_now.change(hour: 13, min: 0))
    @creadas = []
    @sesiones = []
    @cajas = 3.times.map { caja }
    @bulto = medir(@cajas)
  end

  teardown { borrar_lo_creado(@creadas, @sesiones) }

  def caja
    Paquete.create!(tracking: "1ZCAND#{SecureRandom.hex(5).upcase}", cliente: @cliente, tipo_envio: @cer,
                    sucursal_recepcion: sucursales(:miami), manifiesto: @manifiesto,
                    estado: "en_aduana", descripcion: "Zapatos", peso: 2).tap { |c| @creadas << c }
  end

  def medir(cajas)
    bulto, = MedirBulto.new(user: @user).guardar!(paquete_ids: cajas.map(&:id), volumenes: [ { peso: "6" } ])
    @sesiones << bulto.sesion
    bulto
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

  # El primero se frena **adentro** de la transacción, con lo suyo ya
  # bloqueado y validado (justo antes de armar las líneas), y el segundo sale
  # en ese momento. Devuelve lo que le pasó a cada uno, y si el segundo
  # esperó.
  def a_la_vez(primero, segundo)
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
      uno = Thread.new do
        Thread.current[:primero] = true
        en_su_conexion(&primero)
      end
      adentro.pop
      dos = Thread.new { en_su_conexion(&segundo) }
      # El segundo no termina mientras el primero tiene el candado.
      espero = dos.join(1.5).nil?
      seguir << true
      [ uno.value, dos.join(10)&.value, espero ]
    ensure
      seguir << true
      ArmarPreFacturaPorVolumen.singleton_class.define_method(:call, original_sin_atar)
    end
  end

  def pre_facturas_de(cajas)
    PreFactura.joins(:pre_factura_items).where(pre_factura_items: { paquete_id: cajas.map(&:id) }).distinct
  end

  test "dos F9 a la vez: una pre-factura, y el segundo recibe el rechazo de siempre, no un RecordNotUnique" do
    uno, dos, espero = a_la_vez(-> { guardar }, -> { guardar })

    assert espero, "el segundo F9 no esperó al primero"
    assert uno[:pre_factura]&.persisted?, "el primero no guardó: #{uno[:error]&.message}"
    assert dos, "el segundo nunca terminó"
    assert_kind_of GuardarPreFacturaAuditada::NoSePuede, dos[:error], "el segundo tenía que rechazarse: #{dos.inspect}"
    assert_includes dos[:error].message, uno[:pre_factura].numero, "el rechazo nombra la pre-factura que se llevó las cajas"

    assert_equal 1, pre_facturas_de(@cajas).count, "una sola pre-factura cobra estas cajas"
    assert_equal [ uno[:pre_factura].id ] * 3, @cajas.map { |c| c.reload.pre_factura_id }
  end

  # Con #500 (PR-P.6): dos F8 que le agregan **la misma** tanda nueva a la
  # misma pre-factura consolidando. Sin candado, los dos leían las tandas
  # viejas sin la del otro y los dos le agregaban las líneas: el volumen
  # nuevo, cobrado dos veces.
  test "dos F8 a la vez agregando la misma tanda a una consolidando: el volumen entra una sola vez" do
    abierta = GuardarPreFacturaAuditada.new(hoja: @hoja, sesiones: [ @bulto.sesion ], escaneadas: @cajas.map(&:id),
                                            user: @user, modo: :consolidar).call
    nuevas = 2.times.map { caja }
    nuevo = medir(nuevas)
    agregar = lambda do
      GuardarPreFacturaAuditada.new(hoja: @hoja, sesiones: [ @bulto.sesion, nuevo.sesion ], escaneadas: nuevas.map(&:id),
                                    user: @user, modo: :consolidar, pre_factura_id: abierta.id).call
    end

    uno, dos, espero = a_la_vez(agregar, agregar)

    assert espero, "el segundo F8 no esperó al primero"
    assert uno[:pre_factura]&.persisted?, "el primero no guardó: #{uno[:error]&.message}"
    assert dos, "el segundo nunca terminó"
    assert(dos[:pre_factura] || dos[:error].is_a?(GuardarPreFacturaAuditada::NoSePuede),
           "el segundo F8 reventó: #{dos[:error]&.class}: #{dos[:error]&.message}")

    lineas = PreFacturaItem.where(pre_factura_id: abierta.id, origen: "volumen")
    assert_equal [ @bulto.id, nuevo.id ].sort, lineas.pluck(:bulto_id).sort, "cada volumen, una línea"
    assert_equal 5, PreFacturaItem.where(pre_factura_id: abierta.id, origen: "caja_del_volumen").count
    assert_equal [ abierta.id ], pre_facturas_de(@cajas + nuevas).pluck(:id)
    assert (@cajas + nuevas).all? { |c| c.reload.estado == "consolidando_honduras" }
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
