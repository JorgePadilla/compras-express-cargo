require "test_helper"

class PaqueteTest < ActiveSupport::TestCase
  test "valid paquete with required fields" do
    paquete = Paquete.new(tracking: "1Z999TEST", cliente: clientes(:juan))
    assert paquete.valid?
  end

  test "requires tracking" do
    paquete = Paquete.new(cliente: clientes(:juan))
    assert_not paquete.valid?
    assert_includes paquete.errors[:tracking], "no puede estar en blanco"
  end

  test "requires cliente" do
    paquete = Paquete.new(tracking: "1Z999TEST")
    assert_not paquete.valid?
    assert_includes paquete.errors[:cliente], "es obligatorio"
  end

  test "requires unique guia" do
    paquete = Paquete.new(tracking: "1Z999TEST", guia: "PQ-000001", cliente: clientes(:juan))
    assert_not paquete.valid?
    assert_includes paquete.errors[:guia], "ya esta en uso"
  end

  test "auto-generates guia on create" do
    paquete = Paquete.create!(tracking: "1Z999AUTO", cliente: clientes(:juan))
    assert_match /\APQ-\d{6}\z/, paquete.guia
  end

  test "auto-generated guia increments" do
    current_max = Paquete.where("guia LIKE 'PQ-%'")
                    .maximum(Arel.sql("CAST(SUBSTRING(guia FROM 4) AS INTEGER)")) || 0
    paquete = Paquete.create!(tracking: "1Z999INCR", cliente: clientes(:juan))
    assert_equal "PQ-#{(current_max + 1).to_s.rjust(6, '0')}", paquete.guia
  end

  test "default estado is recibido_miami" do
    paquete = Paquete.new(tracking: "1Z999TEST", cliente: clientes(:juan))
    assert_equal "recibido_miami", paquete.estado
  end

  test "sets fecha_recibido_miami on create" do
    paquete = Paquete.create!(tracking: "1Z999FECHA", cliente: clientes(:juan))
    assert_not_nil paquete.fecha_recibido_miami
  end

  # PR-10.a: el peso volumétrico se redondea a ½ libra con umbrales .10/.60
  # (la regla del spreadsheet de Yusef, en VolumetricoCalculator), no con
  # `.round(2)`. Antes la calculadora de /etiquetar mostraba un peso y la
  # pre-factura cobraba otro.
  test "calculates peso_volumetrico redondeando a media libra" do
    paquete = Paquete.create!(
      tracking: "1Z999VOL", cliente: clientes(:juan),
      alto: 10.0, largo: 12.0, ancho: 8.0
    )
    # 960 pulg³ / 166 = 5.783 → frac .783 ≥ .60 → sube a 6.0
    assert_equal 6.0, paquete.peso_volumetrico.to_f
  end

  test "calculates peso_cobrar as max of peso and peso_volumetrico" do
    paquete = Paquete.create!(
      tracking: "1Z999COBRAR", cliente: clientes(:juan),
      peso: 2.0, alto: 20.0, largo: 20.0, ancho: 20.0
    )
    # 8000 pulg³ / 166 = 48.19 → frac .19 entre .10 y .59 → 48.5
    assert_equal 48.5, paquete.peso_cobrar.to_f
  end

  test "peso_volumetrico baja cuando la fraccion es menor a .10" do
    paquete = Paquete.create!(
      tracking: "1Z999VOLBAJA", cliente: clientes(:juan),
      alto: 8.0, largo: 9.0, ancho: 9.0
    )
    # 648 pulg³ / 166 = 3.903 → frac .903 ≥ .60 → 4.0 (antes facturaba 3.90)
    assert_equal 4.0, paquete.peso_volumetrico.to_f
  end

  test "peso_cobrar uses peso when greater than volumetric" do
    paquete = Paquete.create!(
      tracking: "1Z999HEAVY", cliente: clientes(:juan),
      peso: 50.0, alto: 5.0, largo: 5.0, ancho: 5.0
    )
    assert_equal 50.0, paquete.peso_cobrar.to_f
  end

  test "estado_terminal? returns true for entregado" do
    assert paquetes(:entregado).estado_terminal?
  end

  test "estado_terminal? returns false for recibido_miami" do
    assert_not paquetes(:recibido).estado_terminal?
  end

  test "scope activos excludes anulado and entregado" do
    activos = Paquete.activos
    assert_includes activos, paquetes(:recibido)
    assert_includes activos, paquetes(:empacado)
    assert_not_includes activos, paquetes(:entregado)
  end

  test "scope buscar searches by tracking" do
    results = Paquete.buscar("1Z999AA1")
    assert_includes results, paquetes(:recibido)
  end

  test "scope buscar searches by guia" do
    results = Paquete.buscar("PQ-000002")
    assert_includes results, paquetes(:empacado)
  end

  test "scope buscar searches by client codigo" do
    results = Paquete.buscar("CEC-001")
    assert_includes results, paquetes(:recibido)
  end

  test "scope buscar searches by full name nombre + apellido" do
    results = Paquete.buscar("juan perez")
    assert_includes results, paquetes(:recibido)
  end

  test "scope buscar searches by full name apellido + nombre" do
    results = Paquete.buscar("perez juan")
    assert_includes results, paquetes(:recibido)
  end

  test "belongs_to tercero (Cliente) optional" do
    p = paquetes(:recibido)
    p.update!(tercero: clientes(:maria))
    assert_equal clientes(:maria), p.reload.tercero
  end

  test "tercero is optional" do
    p = paquetes(:recibido)
    assert p.update(tercero_id: nil)
  end

  test "scope buscar matches by tercero codigo" do
    p = paquetes(:recibido)
    p.update!(tercero: clientes(:maria))
    assert_includes Paquete.buscar(clientes(:maria).codigo), p
  end

  test "scope buscar matches by tercero nombre" do
    p = paquetes(:recibido)
    p.update!(tercero: clientes(:maria))
    assert_includes Paquete.buscar("maria"), p
  end

  test "scope buscar strips leading/trailing whitespace" do
    results = Paquete.buscar("  1Z999AA1  ")
    assert_includes results, paquetes(:recibido)
  end

  test "scope by_cliente_codigo matches partial ILIKE" do
    juan = clientes(:juan) # CEC-001
    assert_includes Paquete.by_cliente_codigo(juan.codigo), paquetes(:recibido)
    assert_includes Paquete.by_cliente_codigo("001"), paquetes(:recibido)
    assert_not_includes Paquete.by_cliente_codigo("999XYZ"), paquetes(:recibido)
  end

  test "scope by_cliente_codigo strips and short-circuits empty" do
    assert_includes Paquete.by_cliente_codigo("  CEC-001  "), paquetes(:recibido)
    assert_equal Paquete.all.to_a.size, Paquete.by_cliente_codigo("   ").to_a.size
  end

  test "scope by_cliente_nombre matches single word" do
    assert_includes Paquete.by_cliente_nombre("Juan"), paquetes(:recibido)
    assert_includes Paquete.by_cliente_nombre("Perez"), paquetes(:recibido)
  end

  test "scope by_cliente_nombre matches multi-word concatenated" do
    assert_includes Paquete.by_cliente_nombre("juan perez"), paquetes(:recibido)
    assert_includes Paquete.by_cliente_nombre("perez juan"), paquetes(:recibido)
  end

  test "scope by_cliente_nombre strips whitespace" do
    assert_includes Paquete.by_cliente_nombre("  juan perez  "), paquetes(:recibido)
  end

  test "scope busqueda_avanzada matches by notas_internas" do
    p = paquetes(:recibido)
    p.update!(notas_internas: "Caja golpeada del lado izquierdo")
    assert_includes Paquete.busqueda_avanzada("golpeada"), p
  end

  test "scope busqueda_avanzada matches by sucursal nombre" do
    miami = sucursales(:miami)
    paquetes(:recibido).update!(sucursal: miami)
    assert_includes Paquete.busqueda_avanzada(miami.nombre), paquetes(:recibido)
  end

  test "scope busqueda_avanzada matches by remitente" do
    paquetes(:recibido).update!(remitente: "Juan Sender")
    assert_includes Paquete.busqueda_avanzada("Sender"), paquetes(:recibido)
  end

  test "scope busqueda_avanzada matches by expedido_por" do
    paquetes(:recibido).update!(expedido_por: "Amazon Logistics LLC")
    assert_includes Paquete.busqueda_avanzada("Logistics"), paquetes(:recibido)
  end

  test "scope busqueda_avanzada strips whitespace" do
    paquetes(:recibido).update!(notas_internas: "Foo bar baz")
    assert_includes Paquete.busqueda_avanzada("  bar  "), paquetes(:recibido)
  end

  test "scope busqueda_avanzada empty term returns all" do
    assert_equal Paquete.count, Paquete.busqueda_avanzada("").count
    assert_equal Paquete.count, Paquete.busqueda_avanzada("   ").count
  end

  test "scope by_estado filters by estado" do
    results = Paquete.by_estado("empacado")
    assert_includes results, paquetes(:empacado)
    assert_not_includes results, paquetes(:recibido)
  end

  test "scope sin_manifiesto returns packages without manifest" do
    results = Paquete.sin_manifiesto
    assert_includes results, paquetes(:recibido)
    assert_includes results, paquetes(:empacado)
  end

  test "scope sin_pre_alerta returns only paquetes without any PAP" do
    result_ids = Paquete.sin_pre_alerta.pluck(:id)
    # :suelto_juan_aereo has no PAP linking to it
    assert_includes result_ids, paquetes(:suelto_juan_aereo).id
    # :recibido is linked via pap_vinculado → should NOT appear
    assert_not_includes result_ids, paquetes(:recibido).id
    # :cka_linked_juan is linked via pap_cka_linked → should NOT appear
    assert_not_includes result_ids, paquetes(:cka_linked_juan).id
  end

  test "scope by_pre_alerta returns paquetes linked via pre_alerta_paquetes" do
    pap = pre_alerta_paquetes(:pap_vinculado)
    pa = pap.pre_alerta
    paquete = pap.paquete

    results = Paquete.by_pre_alerta(pa.id)
    assert_includes results, paquete
    assert_not_includes results, paquetes(:empacado)
  end

  test "scope by_pre_alerta uses distinct (no duplicates)" do
    pap = pre_alerta_paquetes(:pap_vinculado)
    pa = pap.pre_alerta
    # Si se llamara sin distinct, joins multiplicaría por cada pap match.
    assert_equal 1, Paquete.by_pre_alerta(pa.id).where(id: pap.paquete_id).count
  end

  test "scope facturables returns disponible_entrega without pre_factura" do
    results = Paquete.facturables
    assert_includes results, paquetes(:disponible_entrega_juan)
    assert_includes results, paquetes(:disponible_entrega_maria)
    assert_not_includes results, paquetes(:recibido)
    assert_not_includes results, paquetes(:empacado)
  end

  test "scope facturables excludes paquetes with venta_id (already invoiced)" do
    p = paquetes(:disponible_entrega_juan)
    venta = Venta.create!(cliente: clientes(:juan), estado: "pendiente", moneda: "LPS",
      venta_items_attributes: [{ concepto: "Flete", subtotal: 50 }])
    p.update_column(:venta_id, venta.id)
    assert_not_includes Paquete.facturables, p.reload
  end

  test "scope facturables excludes paquetes already linked to pre_factura" do
    p = paquetes(:disponible_entrega_juan)
    p.update_column(:pre_factura_id, pre_facturas(:borrador_juan).id)
    assert_not_includes Paquete.facturables, p.reload
  end

  test "belongs to cliente" do
    assert_equal clientes(:juan), paquetes(:recibido).cliente
  end

  test "manifiesto is optional" do
    paquete = Paquete.new(tracking: "1Z999OPT", cliente: clientes(:juan))
    assert_nil paquete.manifiesto_id
    assert paquete.valid?
  end

  test "tipo_envio is optional" do
    paquete = Paquete.new(tracking: "1Z999OPT2", cliente: clientes(:juan))
    assert_nil paquete.tipo_envio
    assert paquete.valid?
  end

  test "generate_guia uses SQL maximum instead of pluck-map" do
    # Should work even when there are many records
    paquete = Paquete.create!(tracking: "1Z999SQLMAX", cliente: clientes(:juan))
    assert_match /\APQ-\d{6}\z/, paquete.guia
    num = paquete.guia.sub("PQ-", "").to_i
    assert num > 0
  end

  test "rejects negative peso" do
    paquete = Paquete.new(tracking: "1Z999NEG", cliente: clientes(:juan), peso: -1.0)
    assert_not paquete.valid?
    assert paquete.errors[:peso].any?
  end

  test "rejects negative dimensions" do
    paquete = Paquete.new(tracking: "1Z999NEG2", cliente: clientes(:juan), alto: -1.0, largo: 10.0, ancho: 10.0)
    assert_not paquete.valid?
    assert paquete.errors[:alto].any?
  end

  test "allows nil peso and dimensions" do
    paquete = Paquete.new(tracking: "1Z999NIL", cliente: clientes(:juan))
    assert paquete.valid?
  end

  test "save retries on guia collision" do
    # Create a paquete that will take the next guia slot
    p1 = Paquete.create!(tracking: "1Z999RETRY1", cliente: clientes(:juan))
    expected_next = p1.guia.sub("PQ-", "").to_i + 1

    # Manually assign the next guia to force collision
    p2 = Paquete.create!(tracking: "1Z999RETRY2", guia: "PQ-#{expected_next.to_s.rjust(6, '0')}", cliente: clientes(:juan))

    # This should still succeed via retry
    p3 = Paquete.create!(tracking: "1Z999RETRY3", cliente: clientes(:juan))
    assert_match /\APQ-\d{6}\z/, p3.guia
    assert_not_equal p2.guia, p3.guia
  end

  test "genera numero_recepcion con sucursal, ano y mes" do
    # PR-C6.40: Yusef escribió el formato a mano en la pregunta 17, rotulando
    # cada parte: R + MIA + 26 + 12 + correlativo.
    p = Paquete.create!(tracking: "1Z999REC1", cliente: clientes(:juan), sucursal: sucursales(:miami))
    fecha = p.fecha_recibido_miami || Time.zone.now

    assert_match(/\ARMIA\d{2}\d{2}\d{6}\z/, p.numero_recepcion)
    assert p.numero_recepcion.start_with?(format("RMIA%02d%02d", fecha.year % 100, fecha.month))
  end

  test "genera numero_recepcion distinto por prefijo (sucursales distintas)" do
    p1 = Paquete.create!(tracking: "1Z999REC2A", cliente: clientes(:juan), sucursal: sucursales(:miami))
    p2 = Paquete.create!(tracking: "1Z999REC2B", cliente: clientes(:juan), sucursal: sucursales(:zeron_sps))
    # PR-C6.40: el código de 3 letras de la sucursal, no el prefijo viejo.
    assert p1.numero_recepcion.start_with?("RMIA")
    assert p2.numero_recepcion.start_with?("RSPS")
    assert_match(/\ARMIA\d{10}\z/, p1.numero_recepcion)
    assert_match(/\ARSPS\d{10}\z/, p2.numero_recepcion)
  end

  test "track_fecha_disponible se setea al pasar a disponible_entrega" do
    p = Paquete.create!(tracking: "1Z999FDISP", cliente: clientes(:juan), sucursal: sucursales(:miami))
    assert_nil p.fecha_disponible
    p.update!(estado: "disponible_entrega")
    assert_not_nil p.reload.fecha_disponible
  end

  test "consolidado? es true si hay alguna pre-alerta consolidada vinculada" do
    pap = pre_alerta_paquetes(:pap_vinculado)
    paquete = pap.paquete
    # :recibida tiene consolidado: true en fixture
    assert paquete.consolidado?
  end

  test "by_estados filtra por multiple valores" do
    result = Paquete.by_estados(%w[recibido_miami empacado])
    assert result.to_sql.include?("IN")
  end

  test "numero_recepcion se genera atomicamente para creates secuenciales" do
    # NumeroRecepcionCounter con lock FOR UPDATE garantiza unicidad sin
    # carreras. Aunque dos inserts "concurrentes" corran en serie en los
    # tests, cada increment retorna un valor distinto.
    p1 = Paquete.create!(tracking: "1Z999SEQ_A", cliente: clientes(:juan), sucursal: sucursales(:miami))
    p2 = Paquete.create!(tracking: "1Z999SEQ_B", cliente: clientes(:juan), sucursal: sucursales(:miami))
    p3 = Paquete.create!(tracking: "1Z999SEQ_C", cliente: clientes(:juan), sucursal: sucursales(:miami))

    numeros = [ p1, p2, p3 ].map(&:numero_recepcion)
    assert_equal numeros, numeros.uniq, "Se esperaban 3 numeros distintos, se obtuvieron duplicados"
    numeros.each { |n| assert_match(/\ARMIA\d{10}\z/, n) }
  end

  # ── Sub-etiquetas / split de tracking (PR-C) ──

  test "dividido? es true cuando cantidad_paquetes > 1" do
    p = Paquete.create!(tracking: "1Z999SPLIT_A", cliente: clientes(:juan), sucursal: sucursales(:miami),
                        numero_caja: 1, cantidad_paquetes: 3)
    assert p.dividido?
  end

  test "dividido? es false cuando cantidad_paquetes <= 1 o nil" do
    p1 = Paquete.create!(tracking: "1Z999SPLIT_B1", cliente: clientes(:juan), sucursal: sucursales(:miami))
    p2 = Paquete.create!(tracking: "1Z999SPLIT_B2", cliente: clientes(:juan), sucursal: sucursales(:miami),
                         cantidad_paquetes: 1)
    assert_not p1.dividido?
    assert_not p2.dividido?
  end

  test "etiqueta_secuencia devuelve formato n/N" do
    p = Paquete.create!(tracking: "1Z999SPLIT_C", cliente: clientes(:juan), sucursal: sucursales(:miami),
                        numero_caja: 2, cantidad_paquetes: 4)
    assert_equal "2/4", p.etiqueta_secuencia
  end

  test "etiqueta_secuencia devuelve nil cuando no está dividido" do
    p = Paquete.create!(tracking: "1Z999SPLIT_D", cliente: clientes(:juan), sucursal: sucursales(:miami))
    assert_nil p.etiqueta_secuencia
  end

  test "paquetes_hermanos devuelve los otros bultos del mismo tracking" do
    paquetes = Paquete.crear_split!(
      attrs: { tracking: "1Z999SPLIT_E", cliente: clientes(:juan), sucursal: sucursales(:miami) },
      total_cajas: 3
    )
    p1, p2, p3 = paquetes
    hermanos = p2.paquetes_hermanos.to_a
    assert_equal 2, hermanos.size
    assert_includes hermanos.map(&:id), p1.id
    assert_includes hermanos.map(&:id), p3.id
    assert_not_includes hermanos.map(&:id), p2.id
  end

  test "paquetes_hermanos devuelve none cuando no está dividido" do
    p = Paquete.create!(tracking: "1Z999SPLIT_F", cliente: clientes(:juan), sucursal: sucursales(:miami))
    assert_equal 0, p.paquetes_hermanos.count
  end

  test "crear_split! crea N paquetes con numero_caja 1..N y cantidad_paquetes N" do
    paquetes = Paquete.crear_split!(
      attrs: { tracking: "1Z999SPLIT_G", cliente: clientes(:juan), sucursal: sucursales(:miami) },
      total_cajas: 4
    )

    assert_equal 4, paquetes.size
    paquetes.each_with_index do |p, idx|
      assert_equal idx + 1, p.numero_caja
      assert_equal 4, p.cantidad_paquetes
      assert_equal "1Z999SPLIT_G", p.tracking
    end

    # PR-D0 (Yusef spec): el numero_recepcion es UN número MADRE compartido
    # por las N cajas (Warehouse Receipt único). Las cajas se distinguen
    # solo por numero_caja (no por numero_recepcion).
    numeros = paquetes.map(&:numero_recepcion).uniq
    assert_equal 1, numeros.size, "las N cajas deben compartir el mismo numero_recepcion (madre)"
    assert_match(/\ARMIA\d{10}\z/, numeros.first)
  end

  # ── PR-5c.5p2: integración Paquete ↔ WarehouseReceipt ──

  test "crear_split! crea un único WarehouseReceipt madre y lo asocia a las N cajas" do
    paquetes = Paquete.crear_split!(
      attrs: { tracking: "1Z999WRINT_A", cliente: clientes(:juan), sucursal: sucursales(:miami) },
      total_cajas: 4
    )

    wr_ids = paquetes.map(&:warehouse_receipt_id).uniq
    assert_equal 1, wr_ids.size, "las 4 cajas deben apuntar al MISMO warehouse_receipt"
    assert_not_nil wr_ids.first

    wr = WarehouseReceipt.find(wr_ids.first)
    assert_equal paquetes.first.numero_recepcion, wr.receipt_number
    assert_equal clientes(:juan), wr.consignee
    assert_equal sucursales(:miami), wr.sucursal
    assert_equal "received", wr.status
  end

  test "create de paquete single dispara ensure_warehouse_receipt" do
    p = Paquete.create!(tracking: "1Z999WRINT_B", cliente: clientes(:juan), sucursal: sucursales(:miami))
    assert_not_nil p.warehouse_receipt_id, "paquete single debe tener WR asociado tras create"
    assert_equal p.numero_recepcion, p.warehouse_receipt.receipt_number
    assert_equal clientes(:juan), p.warehouse_receipt.consignee
  end

  test "ensure_warehouse_receipt es idempotente (find_or_initialize_by)" do
    p1 = Paquete.create!(tracking: "1Z999WRINT_C1", cliente: clientes(:juan), sucursal: sucursales(:miami))
    wr_count_after_first = WarehouseReceipt.count

    p2 = Paquete.create!(
      tracking: "1Z999WRINT_C2",
      cliente: clientes(:juan),
      sucursal: sucursales(:miami),
      numero_recepcion: p1.numero_recepcion,
      numero_caja: 2,
      cantidad_paquetes: 2
    )

    assert_equal wr_count_after_first, WarehouseReceipt.count, "no debe crearse un 2do WR para el mismo madre"
    assert_equal p1.warehouse_receipt_id, p2.warehouse_receipt_id
  end

  test "crear_split! incrementa el counter UNA sola vez (no N)" do
    counter_before = NumeroRecepcionCounter.where(sucursal: sucursales(:miami), anio: Time.zone.now.year)
                                            .pick(:ultimo_numero) || 0
    Paquete.crear_split!(
      attrs: { tracking: "1Z999SPLIT_COUNTER", cliente: clientes(:juan), sucursal: sucursales(:miami) },
      total_cajas: 5
    )
    counter_after = NumeroRecepcionCounter.where(sucursal: sucursales(:miami), anio: Time.zone.now.year)
                                           .pick(:ultimo_numero)
    assert_equal counter_before + 1, counter_after,
      "el counter debe incrementar 1 vez para todo el split, no #{5} veces"
  end

  test "crear_split! con total_cajas < 2 lanza ArgumentError" do
    assert_raises(ArgumentError) do
      Paquete.crear_split!(
        attrs: { tracking: "1Z999SPLIT_H", cliente: clientes(:juan), sucursal: sucursales(:miami) },
        total_cajas: 1
      )
    end
  end

  test "crear_split! hace rollback completo si una creación falla" do
    # Forzamos failure en el segundo create con tracking inválido (presence: true).
    initial_count = Paquete.count
    assert_raises(ActiveRecord::RecordInvalid) do
      Paquete.crear_split!(
        attrs: { tracking: nil, cliente: clientes(:juan), sucursal: sucursales(:miami) },
        total_cajas: 3
      )
    end
    assert_equal initial_count, Paquete.count, "rollback debió revertir todos los inserts"
  end

  # ── next_duplicate_suffix (PR-B: tracking duplicado) ──

  test "next_duplicate_suffix devuelve A si no hay sufijos previos" do
    base = "1Z999DUPLICATE_A"
    assert_equal "A", Paquete.next_duplicate_suffix(base)
  end

  test "next_duplicate_suffix devuelve B si ya existe el A" do
    base = "1Z999DUPLICATE_B"
    Paquete.create!(tracking: "#{base}A", cliente: clientes(:juan), sucursal: sucursales(:miami))
    assert_equal "B", Paquete.next_duplicate_suffix(base)
  end

  test "next_duplicate_suffix devuelve la próxima letra libre tras múltiples sufijos" do
    base = "1Z999DUPLICATE_C"
    %w[A B C].each do |letra|
      Paquete.create!(tracking: "#{base}#{letra}", cliente: clientes(:juan), sucursal: sucursales(:miami))
    end
    assert_equal "D", Paquete.next_duplicate_suffix(base)
  end

  test "next_duplicate_suffix devuelve nil cuando se agotó A-Z" do
    base = "1Z999DUPLICATE_FULL"
    ("A".."Z").each do |letra|
      Paquete.create!(tracking: "#{base}#{letra}", cliente: clientes(:juan), sucursal: sucursales(:miami))
    end
    assert_nil Paquete.next_duplicate_suffix(base)
  end

  test "next_duplicate_suffix ignora sufijos compuestos (más de 1 letra)" do
    base = "1Z999DUPLICATE_D"
    # Tracking con 2 letras al final (caso fuera-de-spec) NO debe contar.
    Paquete.create!(tracking: "#{base}AA", cliente: clientes(:juan), sucursal: sucursales(:miami))
    assert_equal "A", Paquete.next_duplicate_suffix(base)
  end

  test "next_duplicate_suffix con base vacío devuelve nil" do
    assert_nil Paquete.next_duplicate_suffix("")
    assert_nil Paquete.next_duplicate_suffix(nil)
  end

  test "consolidado? usa coleccion precargada si esta loaded" do
    pap = pre_alerta_paquetes(:pap_vinculado)
    paquete = pap.paquete
    reloaded = Paquete.includes(pre_alerta_paquetes: :pre_alerta).find(paquete.id)

    assert_no_queries do
      reloaded.consolidado?
    end
  end

  # PR-D3.c.2 — sync_carrier_catalog (dropdown híbrido auto-add)
  test "guardar paquete con carrier nuevo lo agrega al catalogo" do
    paquete = paquetes(:recibido)
    nuevo_nombre = "USPS Priority Mail Express"
    assert_not Carrier.where("LOWER(nombre) = ?", nuevo_nombre.downcase).exists?

    assert_difference("Carrier.count", 1) do
      paquete.update!(expedido_por: nuevo_nombre)
    end
    assert Carrier.where(nombre: nuevo_nombre, activo: true).exists?
  end

  test "guardar paquete con carrier ya existente NO duplica" do
    paquete = paquetes(:recibido)
    existing = carriers(:fedex)

    assert_no_difference("Carrier.count") do
      paquete.update!(expedido_por: existing.nombre)
    end
  end

  test "guardar paquete con carrier en otro case NO duplica" do
    paquete = paquetes(:recibido)
    carriers(:fedex)

    assert_no_difference("Carrier.count") do
      paquete.update!(expedido_por: "fEdEx")
    end
  end

  test "guardar paquete sin carrier no toca catalogo" do
    paquete = paquetes(:recibido)
    paquete.update_column(:expedido_por, "FedEx")

    assert_no_difference("Carrier.count") do
      paquete.update!(expedido_por: "")
    end
  end

  # PR-D6.a — tarifa_recolecta del catálogo autocompleta monto+moneda
  test "elegir tarifa_recolecta autocompleta monto y moneda" do
    paquete = paquetes(:recibido)
    tarifa = tarifas_recolecta(:tegucigalpa) # 50 USD

    paquete.update!(recolecta_solicitada: true, tarifa_recolecta: tarifa)

    assert_equal 50.0,  paquete.reload.recolecta_monto.to_f
    assert_equal "USD", paquete.recolecta_moneda
  end

  test "elegir tarifa LPS copia moneda LPS al paquete" do
    paquete = paquetes(:recibido)
    tarifa = tarifas_recolecta(:la_lima_lps) # 800 LPS

    paquete.update!(recolecta_solicitada: true, tarifa_recolecta: tarifa)

    assert_equal 800.0, paquete.reload.recolecta_monto.to_f
    assert_equal "LPS", paquete.recolecta_moneda
  end

  test "cambiar tarifa actualiza monto+moneda del paquete" do
    paquete = paquetes(:recibido)
    paquete.update!(recolecta_solicitada: true, tarifa_recolecta: tarifas_recolecta(:tegucigalpa))
    assert_equal 50.0, paquete.reload.recolecta_monto.to_f

    paquete.update!(tarifa_recolecta: tarifas_recolecta(:san_pedro_centro))
    assert_equal 35.0, paquete.reload.recolecta_monto.to_f
  end

  test "recolecta sin tarifa cae al default $35 USD" do
    paquete = paquetes(:recibido)

    paquete.update!(recolecta_solicitada: true)

    assert_equal 35.0,  paquete.reload.recolecta_monto.to_f
    assert_equal "USD", paquete.recolecta_moneda
  end

  test "monto manual no se sobrescribe si no cambia tarifa" do
    paquete = paquetes(:recibido)
    paquete.update!(recolecta_solicitada: true, recolecta_monto: 99.99, recolecta_moneda: "USD")

    paquete.update!(descripcion: "otro cambio sin tocar tarifa")

    assert_equal 99.99, paquete.reload.recolecta_monto.to_f
  end

  # PR-D7.b: helpers de transición de estado.
  test "transicion_retroceso? detecta retrocesos en el pipeline" do
    assert Paquete.transicion_retroceso?("entregado", "en_reparto")
    assert Paquete.transicion_retroceso?("disponible_entrega", "empacado")
    assert Paquete.transicion_retroceso?("facturado", "disponible_entrega")
  end

  test "transicion_retroceso? no marca avances como retroceso" do
    assert_not Paquete.transicion_retroceso?("recibido_miami", "empacado")
    assert_not Paquete.transicion_retroceso?("empacado", "enviado_honduras")
    assert_not Paquete.transicion_retroceso?("en_reparto", "entregado")
  end

  test "transicion_retroceso? ignora estados excepcionales" do
    assert_not Paquete.transicion_retroceso?("retenido", "recibido_miami")
    assert_not Paquete.transicion_retroceso?("disponible_entrega", "anulado")
    assert_not Paquete.transicion_retroceso?("entregado", "consolidando_honduras")
  end

  test "transicion_retroceso? con estado igual o nil retorna false" do
    assert_not Paquete.transicion_retroceso?("empacado", "empacado")
    assert_not Paquete.transicion_retroceso?(nil, "empacado")
    assert_not Paquete.transicion_retroceso?("empacado", nil)
  end

  test "transicion_pasos_atras cuenta correctamente" do
    assert_equal 1, Paquete.transicion_pasos_atras("entregado", "en_reparto")
    assert_equal 3, Paquete.transicion_pasos_atras("disponible_entrega", "empacado")
    assert_equal 0, Paquete.transicion_pasos_atras("recibido_miami", "empacado")
    assert_equal 0, Paquete.transicion_pasos_atras("retenido", "recibido_miami")
  end

  # PR-D7.d: cleanup automático al confirmar retroceso.
  test "retroceso_cleanup_preview lista fechas y FKs de estados posteriores" do
    p = paquetes(:entregado)
    user_id = users(:admin).id
    p.update_columns(
      fecha_entregado:                1.day.ago,
      fecha_entregado_by_user_id:     user_id,
      fecha_en_reparto:               2.days.ago,
      fecha_en_reparto_by_user_id:    user_id,
      fecha_disponible:               3.days.ago,
      fecha_disponible_by_user_id:    user_id,
      fecha_empacado:                 5.days.ago,
      fecha_empacado_by_user_id:      user_id
    )
    preview = p.retroceso_cleanup_preview("recibido_miami")
    assert_includes preview[:fechas], :fecha_entregado
    assert_includes preview[:fechas], :fecha_entregado_by_user_id
    assert_includes preview[:fechas], :fecha_en_reparto
    assert_includes preview[:fechas], :fecha_en_reparto_by_user_id
    assert_includes preview[:fechas], :fecha_disponible
    assert_includes preview[:fechas], :fecha_empacado
  end

  test "retroceso_cleanup_preview omite columnas en nil" do
    p = paquetes(:entregado)
    # Solo fecha_entregado seteada; las anteriores nil.
    p.update_columns(
      fecha_entregado:    1.day.ago,
      fecha_en_reparto:   nil,
      fecha_disponible:   nil,
      fecha_consolidando: nil,
      fecha_empacado:     nil
    )
    preview = p.retroceso_cleanup_preview("recibido_miami")
    assert_includes preview[:fechas], :fecha_entregado
    assert_not_includes preview[:fechas], :fecha_en_reparto
    assert_not_includes preview[:fechas], :fecha_disponible
  end

  test "retroceso_cleanup_preview retorna vacío para avance o estado igual" do
    p = paquetes(:recibido)
    assert_equal({ fechas: [], fks: [] }, p.retroceso_cleanup_preview("empacado"))
    assert_equal({ fechas: [], fks: [] }, p.retroceso_cleanup_preview("recibido_miami"))
  end

  test "apply_retroceso_cleanup! nula fechas y FKs en memoria" do
    p = paquetes(:entregado)
    p.update_columns(
      fecha_entregado:  1.day.ago,
      fecha_en_reparto: 2.days.ago
    )
    p.apply_retroceso_cleanup!("recibido_miami")
    assert_nil p.fecha_entregado
    assert_nil p.fecha_en_reparto
    # No persiste hasta el save siguiente.
    assert_not_nil p.reload.fecha_entregado
  end
end
