require "test_helper"
require_relative "../support/con_app_host"

# Los generadores de `DatosDePrueba`: que lo que crean es lo mismo que crea el
# sistema, y que la pistola del manifiesto lo deja entrar.
class DatosDePruebaTest < ActiveSupport::TestCase
  include ConAppHost

  setup do
    @cer   = tipo_envios(:cer)
    @tgu   = sucursales(:humuya_tgu)
    @admin = users(:admin)
  end

  def pre_alertas(**opciones)
    DatosDePrueba::PreAlertas.new(tipo_envio: @cer, sucursal_retiro: @tgu, user: @admin, **opciones)
  end

  def manifiesto_a_tgu(**opciones)
    DatosDePrueba::ArmarManifiesto.new(tipo_envio_ids: [ @cer.id ], sucursal_entrega_ids: [ @tgu.id ],
                                       user: @admin, **opciones).crear
  end

  test "habilitados en local y en staging, nunca en producción" do
    assert DatosDePrueba.habilitados?
    en_staging { assert DatosDePrueba.habilitados? }
    en_produccion { assert_not DatosDePrueba.habilitados? }
    # Falla cerrado: un servidor con un host que no es el de staging es producción.
    en_servidor("otro-host.example.com") { assert_not DatosDePrueba.habilitados? }
  end

  test "recibidas en Miami: número de recepción, sucursal de retiro y la pre-alerta en «recibido»" do
    filas = pre_alertas(cantidad: 3, recibir: true).crear

    assert_equal 3, filas.size
    filas.each do |fila|
      paquete = fila.paquetes.sole
      assert paquete.recibido_miami?
      assert paquete.numero_recepcion.present?, "sin número de recepción no hay etiqueta que escanear"
      assert_equal @tgu, paquete.sucursal
      assert_equal @cer, paquete.tipo_envio
      assert paquete.tracking.start_with?(DatosDePrueba::PREFIJO)
      assert_equal "recibido", fila.pre_alerta.reload.estado
      assert_equal paquete, fila.pre_alerta.pre_alerta_paquetes.sole.paquete, "el esperado es el que se recibe, no uno nuevo al lado"
    end
  end

  test "sin cliente, va al cliente de prueba de la sucursal, uno solo" do
    pre_alertas(cantidad: 2).crear
    pre_alertas(cantidad: 1).crear

    clientes = DatosDePrueba.paquetes.map(&:cliente).uniq
    assert_equal 1, clientes.size
    assert_equal "#{DatosDePrueba::PREFIJO}-#{@tgu.codigo}", clientes.sole.codigo
    assert_equal @tgu, clientes.sole.sucursal_retiro
  end

  test "sin recibir quedan esperando, para probar /etiquetar" do
    fila = pre_alertas(cantidad: 1, recibir: false).crear.sole

    assert_equal "pre_alerta_estado", fila.paquetes.sole.estado
    assert_equal "pre_alerta", fila.pre_alerta.reload.estado
  end

  test "con volúmenes es un envío partido: mismo número madre, mismo tracking, una caja por volumen" do
    fila = pre_alertas(cantidad: 1, volumenes: 3, recibir: true).crear.sole

    cajas = fila.paquetes
    assert_equal [ 1, 2, 3 ], cajas.map(&:numero_caja)
    assert_equal 1, cajas.map(&:numero_recepcion).uniq.size
    assert_equal 1, cajas.map(&:tracking).uniq.size
    assert cajas.all?(&:recibido_miami?)
  end

  test "volúmenes sin recibir no se puede: el envío se parte al recibir" do
    generador = pre_alertas(cantidad: 1, volumenes: 2, recibir: false)

    assert_no_difference -> { PreAlerta.count } do
      assert_nil generador.crear
    end
    assert_match "Recibir en Miami", generador.errores.to_sentence
  end

  test "un tracking tecleado a mano que empieza con PRUEBA no cuenta como de prueba" do
    a_mano = Paquete.create!(cliente: clientes(:juan), tracking: "PRUEBA1", estado: "recibido_miami",
                             tipo_envio: @cer, sucursal: @tgu, sucursal_recepcion: sucursales(:miami))
    pre_alertas(cantidad: 1).crear

    assert_not_includes DatosDePrueba.paquetes, a_mano
    assert_equal 1, DatosDePrueba.paquetes.count
  end

  test "la cantidad se acota" do
    assert_equal 1, pre_alertas(cantidad: "0").crear.size
    assert_equal 1, pre_alertas(cantidad: "abc").crear.size
  end

  test "el manifiesto: oficial, desde Miami, con sus tipos, sus sucursales y cajas con peso" do
    armar = DatosDePrueba::ArmarManifiesto.new(tipo_envio_ids: [ @cer.id ], sucursal_entrega_ids: [ @tgu.id ],
                                               cajas: 2, user: @admin)
    manifiesto = armar.crear

    assert manifiesto.tipo_oficial?
    assert manifiesto.creado?
    assert_equal [ @cer ], manifiesto.tipo_envios.to_a
    assert_equal [ @tgu ], manifiesto.sucursales_entrega.to_a
    assert_equal sucursales(:miami), manifiesto.sucursal_origen
    assert_equal 2, manifiesto.cajas.count
    assert manifiesto.cajas.all? { |c| c.peso.to_d.positive? }, "sin peso no se finaliza (C31-07)"
    assert_equal 0, armar.metidos
  end

  test "lo que se crea, la pistola del manifiesto lo deja entrar" do
    filas = pre_alertas(cantidad: 2, recibir: true).crear
    manifiesto = manifiesto_a_tgu(cajas: 1)

    escaneo = EscaneoDeManifiesto.new(manifiesto)
    filas.flat_map(&:paquetes).each do |paquete|
      resultado = escaneo.por_codigo(paquete.numero_recepcion)
      assert resultado.ok?, "#{paquete.numero_recepcion}: #{resultado.tipo}"
    end
  end

  test "llenar mete solo los que entran, cada uno en una caja y empacado" do
    pre_alertas(cantidad: 2, recibir: true).crear
    # Otra sucursal: este manifiesto no lo acepta.
    DatosDePrueba::PreAlertas.new(tipo_envio: @cer, sucursal_retiro: sucursales(:san_manuel), cantidad: 1, user: @admin).crear

    armar = DatosDePrueba::ArmarManifiesto.new(tipo_envio_ids: [ @cer.id ], sucursal_entrega_ids: [ @tgu.id ],
                                               cajas: 2, llenar: true, user: @admin)
    manifiesto = armar.crear

    assert_equal 2, armar.metidos
    adentro = manifiesto.paquetes.to_a
    assert_equal 2, adentro.size
    assert adentro.all?(&:empacado?)
    assert adentro.all?(&:caja_manifiesto_id), "llenado sin caja es el «sin escanear» que se quiso evitar"
  end

  test "un manifiesto sin tipo de envío no se crea" do
    armar = DatosDePrueba::ArmarManifiesto.new(tipo_envio_ids: [], sucursal_entrega_ids: [ @tgu.id ], user: @admin)

    assert_no_difference -> { Manifiesto.count } do
      assert_nil armar.crear
    end
    assert armar.errores.any?
  end
end
