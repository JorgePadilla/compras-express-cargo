require "test_helper"

# PR-C29.20 · Las pantallas de listas no hacen una consulta por renglón.
#
# Jorge, 2026-10-09: *"let's make sure we don't have n+1 in the code, if we
# have let's improve it"*. Las fixtures traen dos o tres registros de cada
# cosa, y con eso un N+1 no se ve. Acá cada pantalla se mide dos veces: con 3
# renglones y con 15. Si las consultas crecen con los renglones, hay un N+1.
# Se tolera una diferencia chica (una paginación, un «hay más») pero no una
# por renglón.
#
# El cazador de `test/support/cazar_n_mas_1.rb` encuentra los candidatos en
# toda la suite; esto fija los que se arreglaron para que no vuelvan.
class SinNMas1Test < ActionDispatch::IntegrationTest
  TOLERANCIA = 2

  setup do
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
    @n = 0
  end

  # Las consultas de verdad de un request: sin las del esquema, sin las de
  # transacción y sin las que salen del caché de consultas.
  def consultas_de
    total = 0
    contar = lambda do |*, payload|
      next if payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name])

      total += 1
    end
    ActiveSupport::Notifications.subscribed(contar, "sql.active_record") { yield }
    total
  end

  # Siembra 3, mide; siembra 12 más, mide; las dos tienen que ser casi iguales.
  def assert_no_crece_con_los_renglones(nombre)
    3.times { yield(@n += 1) }
    pocas = consultas_de { get_pantalla }
    assert_response :success
    12.times { yield(@n += 1) }
    muchas = consultas_de { get_pantalla }
    assert_response :success

    puts "#{nombre}\t#{pocas}\t#{muchas}" if ENV["VER_CONSULTAS"]
    assert_operator muchas - pocas, :<=, TOLERANCIA,
                    "#{nombre}: #{pocas} consultas con 3 renglones y #{muchas} con 15 — crece con los renglones (N+1)"
  end

  def paquete(i, **extra)
    Paquete.create!({ tracking: "1ZNMAS1#{i.to_s.rjust(6, '0')}", cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                      sucursal_recepcion: sucursales(:miami), estado: "recibido_miami", descripcion: "Zapatos", peso: 2 }.merge(extra))
  end

  def manifiesto(i, **extra)
    Manifiesto.create!({ numero: "MNMAS1#{i.to_s.rjust(6, '0')}", estado: "creado", tipo_envio: "AEREO",
                         sucursal_origen: sucursales(:miami), user: users(:admin), tipo_envios: [ tipo_envios(:cer) ] }.merge(extra))
  end

  test "/paquetes" do
    @pantalla = -> { get paquetes_path }
    assert_no_crece_con_los_renglones("/paquetes") { |i| paquete(i) }
  end

  # C30-12 · Cada volumen con su cliente, quién lo midió, las cajas de la tanda
  # y su pre-factura.
  test "/medicion/volumenes" do
    @pantalla = -> { get volumenes_medicion_index_path }
    assert_no_crece_con_los_renglones("/medicion/volumenes") do |i|
      sesion = "nmas1-#{i}"
      paquete(i, numero_recepcion: "SPSNMAS1#{i}").update_columns(medicion_sesion: sesion, medido_at: Time.current)
      bulto = Bulto.create!(cliente: clientes(:juan), user: users(:admin), sesion: sesion, medido_at: Time.current,
                            peso: 3, alto: 10, largo: 10, ancho: 10)
      pf = PreFactura.create!(cliente: clientes(:juan), numero: "PFVOL#{i}", estado: "creado", creado_por: users(:admin))
      pf.pre_factura_items.create!(concepto: "Flete", subtotal: 10, origen: PreFacturaItem::ORIGENES.first, bulto: bulto)
    end
  end

  test "/pre_alertas" do
    @pantalla = -> { get pre_alertas_path }
    assert_no_crece_con_los_renglones("/pre_alertas") do |i|
      pa = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:aereo), titulo: "PA #{i}", estado: "pre_alerta")
      pa.pre_alerta_paquetes.create!(tracking: "TRK#{i}", descripcion: "Ropa")
    end
  end

  test "/manifiestos" do
    @pantalla = -> { get manifiestos_path }
    assert_no_crece_con_los_renglones("/manifiestos") do |i|
      m = manifiesto(i)
      m.cajas.create!(tamano_caja: tamano_cajas(:mediana), peso: 10, user: users(:admin))
      paquete(i, manifiesto: m)
    end
  end

  test "la ficha de un manifiesto, con sus cajas y paquetes" do
    m = manifiesto(0)
    @pantalla = -> { get manifiesto_path(m) }
    assert_no_crece_con_los_renglones("/manifiestos/:id") do |i|
      caja = m.cajas.create!(tamano_caja: tamano_cajas(:mediana), peso: 10, user: users(:admin))
      paquete(i, manifiesto: m, caja_manifiesto_id: caja.id)
    end
  end

  test "empacar un manifiesto" do
    m = manifiesto(0)
    @pantalla = -> { get manifiesto_empacar_path(m) }
    assert_no_crece_con_los_renglones("/manifiestos/:id/empacar") do |i|
      caja = m.cajas.create!(tamano_caja: tamano_cajas(:mediana), peso: 10, user: users(:admin))
      paquete(i, manifiesto: m, caja_manifiesto_id: caja.id)
    end
  end

  test "/clientes" do
    @pantalla = -> { get clientes_path }
    assert_no_crece_con_los_renglones("/clientes") do |i|
      Cliente.create!(codigo: "NMAS-#{i}", nombre: "Cliente #{i}", sucursal_retiro: sucursales(:zeron_sps))
    end
  end

  test "/sucursales" do
    @pantalla = -> { get sucursales_path }
    assert_no_crece_con_los_renglones("/sucursales") do |i|
      s = Sucursal.create!(codigo: "N#{i}X", nombre: "Sucursal #{i}")
      paquete(i, sucursal: s)
    end
  end

  test "/ventas" do
    @pantalla = -> { get ventas_path }
    assert_no_crece_con_los_renglones("/ventas") do |i|
      v = Venta.create!(cliente: clientes(:juan), numero: "VNMAS#{i}", estado: "pendiente", total: 10, creado_por: users(:admin))
      v.venta_items.create!(concepto: "Flete", subtotal: 10, paquete: paquete(i))
    end
  end

  test "/pre_facturas" do
    @pantalla = -> { get pre_facturas_path }
    assert_no_crece_con_los_renglones("/pre_facturas") do |i|
      pf = PreFactura.create!(cliente: clientes(:juan), numero: "PFNMAS#{i}", estado: "creado", creado_por: users(:admin))
      pf.pre_factura_items.create!(concepto: "Flete", subtotal: 10, origen: PreFacturaItem::ORIGENES.first, paquete: paquete(i))
    end
  end

  test "/recepcion_carga" do
    @pantalla = -> { get recepcion_carga_index_path }
    assert_no_crece_con_los_renglones("/recepcion_carga") do |i|
      m = manifiesto(i, estado: "enviado")
      m.cajas.create!(tamano_caja: tamano_cajas(:mediana), peso: 10, user: users(:admin))
    end
  end

  # C30-09 · La fila cuenta en memoria también los **paquetes** (`ProgresoDe
  # Recepcion`): los del interno, y los que viajaron sin caja en el oficial.
  # Con cajas solamente, este lint no veía si `includes(:paquetes)` faltaba.
  test "/recepcion_carga con manifiestos que viajaron sin cajas" do
    @pantalla = -> { get recepcion_carga_index_path }
    assert_no_crece_con_los_renglones("/recepcion_carga sin cajas") do |i|
      paquete(i, manifiesto: manifiesto(i, estado: "enviado"), estado: "enviado_honduras")
    end
  end

  test "el panel de medición de un manifiesto" do
    m = manifiesto(0, estado: "enviado")
    @pantalla = -> { get panel_medicion_index_path(manifiesto_id: m.id) }
    assert_no_crece_con_los_renglones("/medicion/panel") do |i|
      paquete(i, manifiesto: m).update!(estado: "en_aduana")
    end
  end

  test "el listado de paquetes del manifiesto" do
    m = manifiesto(0)
    @pantalla = -> { get listado_manifiesto_path(m) }
    assert_no_crece_con_los_renglones("/manifiestos/:id/listado") do |i|
      caja = m.cajas.create!(tamano_caja: tamano_cajas(:mediana), peso: 10, user: users(:admin))
      paquete(i, manifiesto: m, caja_manifiesto_id: caja.id)
    end
  end

  test "la hoja del manifiesto y las 4×6 de sus cajas" do
    m = manifiesto(0)
    [ -> { get documento_manifiesto_path(m) }, -> { get etiquetas_manifiesto_cajas_path(m) } ].each_with_index do |pantalla, k|
      @pantalla = pantalla
      assert_no_crece_con_los_renglones(k.zero? ? "/manifiestos/:id/documento" : "/manifiestos/:id/cajas/etiquetas") do |i|
        caja = m.cajas.create!(tamano_caja: tamano_cajas(:mediana), peso: 10, user: users(:admin))
        paquete(i + 100 * k, manifiesto: m, caja_manifiesto_id: caja.id)
      end
    end
  end

  test "editar una pre-alerta con muchos paquetes" do
    pa = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:aereo), titulo: "Grande", estado: "pre_alerta")
    @pantalla = -> { get edit_pre_alerta_path(pa) }
    assert_no_crece_con_los_renglones("/pre_alertas/:id/edit") do |i|
      pa.pre_alerta_paquetes.create!(tracking: "TRKEDIT#{i}", descripcion: "Ropa", paquete: paquete(i))
    end
  end

  test "/tareas" do
    @pantalla = -> { get tareas_path }
    assert_no_crece_con_los_renglones("/tareas") do |i|
      Tarea.create!(titulo: "Tarea #{i}", estado: "pendiente", departamento: "miami", origen: "manual",
                    paquete: paquete(i), cliente: clientes(:juan), asignado_a: users(:admin))
    end
  end

  test "/entregas" do
    @pantalla = -> { get entregas_path }
    assert_no_crece_con_los_renglones("/entregas") do |i|
      e = Entrega.create!(numero: "ENMAS#{i}", cliente: clientes(:juan), tipo_entrega: "retiro_oficina", estado: "pendiente",
                          receptor_nombre: "Juan", receptor_identidad: "0801", creado_por: users(:admin))
      paquete(i, entrega: e)
    end
  end

  test "/cotizaciones" do
    @pantalla = -> { get cotizaciones_path }
    assert_no_crece_con_los_renglones("/cotizaciones") do |i|
      Cotizacion.create!(numero: "CNMAS#{i}", cliente: clientes(:juan), estado: "borrador", creado_por: users(:admin))
    end
  end

  test "el Home" do
    @pantalla = -> { get root_path }
    assert_no_crece_con_los_renglones("/") do |i|
      paquete(i)
      Venta.create!(cliente: clientes(:juan), numero: "VHOME#{i}", estado: "pendiente", total: 10, creado_por: users(:admin))
    end
  end

  private

  def get_pantalla = @pantalla.call
end

# Lo mismo del lado del cliente: el portal lista sus pre-alertas y sus facturas.
class SinNMas1PortalTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: clientes(:juan).email, password: "Cliente123!" }
  end

  def consultas_de
    total = 0
    contar = ->(*, payload) { total += 1 unless payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name]) }
    ActiveSupport::Notifications.subscribed(contar, "sql.active_record") { yield }
    total
  end

  def medir(ruta, sembrar)
    n = 0
    3.times { sembrar.call(n += 1) }
    pocas = consultas_de { get ruta }
    assert_response :success
    12.times { sembrar.call(n += 1) }
    muchas = consultas_de { get ruta }
    puts "#{ruta.gsub(/\d+/, ':id')}\t#{pocas}\t#{muchas}" if ENV["VER_CONSULTAS"]
    assert_operator muchas - pocas, :<=, SinNMas1Test::TOLERANCIA, "#{ruta}: #{pocas} consultas con 3 y #{muchas} con 15 (N+1)"
  end

  test "las pre-alertas del portal" do
    medir(cuenta_pre_alertas_path, lambda do |i|
      pa = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:aereo), titulo: "Portal #{i}", estado: "pre_alerta")
      pa.pre_alerta_paquetes.create!(tracking: "TRKPORTAL#{i}", descripcion: "Ropa")
    end)
  end

  # La gemela de «editar una pre-alerta» del admin: cada renglón mira el
  # estado de su paquete.
  test "editar una pre-alerta del portal con muchos paquetes" do
    pa = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:aereo), titulo: "Portal grande", estado: "pre_alerta")
    medir(edit_cuenta_pre_alerta_path(pa), lambda do |i|
      p = Paquete.create!(tracking: "1ZPORTAL#{i.to_s.rjust(6, '0')}", cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                          sucursal_recepcion: sucursales(:miami), estado: "recibido_miami", descripcion: "Ropa", peso: 1)
      pa.pre_alerta_paquetes.create!(tracking: "TRKPEDIT#{i}", descripcion: "Ropa", paquete: p)
    end)
  end

  test "las facturas del portal" do
    medir(cuenta_facturas_path, lambda do |i|
      Venta.create!(cliente: clientes(:juan), numero: "VPORTAL#{i}", estado: "pendiente", total: 10)
    end)
  end
end
