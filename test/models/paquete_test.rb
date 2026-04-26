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

  test "calculates peso_volumetrico" do
    paquete = Paquete.create!(
      tracking: "1Z999VOL", cliente: clientes(:juan),
      alto: 10.0, largo: 12.0, ancho: 8.0
    )
    expected = (10.0 * 12.0 * 8.0 / 166.0).round(2)
    assert_equal expected, paquete.peso_volumetrico.to_f
  end

  test "calculates peso_cobrar as max of peso and peso_volumetrico" do
    paquete = Paquete.create!(
      tracking: "1Z999COBRAR", cliente: clientes(:juan),
      peso: 2.0, alto: 20.0, largo: 20.0, ancho: 20.0
    )
    vol = (20.0 * 20.0 * 20.0 / 166.0).round(2)
    assert_equal vol, paquete.peso_cobrar.to_f
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

  test "scope facturables returns disponible_entrega without pre_factura" do
    results = Paquete.facturables
    assert_includes results, paquetes(:disponible_entrega_juan)
    assert_includes results, paquetes(:disponible_entrega_maria)
    assert_not_includes results, paquetes(:recibido)
    assert_not_includes results, paquetes(:empacado)
  end

  test "scope facturables excludes paquetes with venta_id (reserved by proforma)" do
    p = paquetes(:disponible_entrega_juan)
    proforma = Venta.create!(cliente: clientes(:juan), estado: "proforma", moneda: "LPS",
      venta_items_attributes: [{ concepto: "Flete", subtotal: 50 }])
    p.update_column(:venta_id, proforma.id)
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

  test "genera numero_recepcion con prefijo de la sucursal y formato anual" do
    p = Paquete.create!(tracking: "1Z999REC1", cliente: clientes(:juan), sucursal: sucursales(:miami))
    # Formato: <PREFIX><AÑO 7-DIG><CONTADOR 6-DIG>, ej. RM0002026000001
    anio = (p.fecha_recibido_miami&.year || Time.zone.now.year)
    assert_match(/\ARM\d{7}\d{6}\z/, p.numero_recepcion)
    assert p.numero_recepcion.start_with?("RM#{anio.to_s.rjust(7, '0')}")
  end

  test "genera numero_recepcion distinto por prefijo (sucursales distintas)" do
    p1 = Paquete.create!(tracking: "1Z999REC2A", cliente: clientes(:juan), sucursal: sucursales(:miami))
    p2 = Paquete.create!(tracking: "1Z999REC2B", cliente: clientes(:juan), sucursal: sucursales(:zeron_sps))
    assert p1.numero_recepcion.start_with?("RM")
    assert p2.numero_recepcion.start_with?("RS")
    assert_match(/\ARM\d{13}\z/, p1.numero_recepcion)
    assert_match(/\ARS\d{13}\z/, p2.numero_recepcion)
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
    numeros.each { |n| assert_match(/\ARM\d{13}\z/, n) }
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

    # numero_recepcion debe ser único por bulto
    numeros = paquetes.map(&:numero_recepcion)
    assert_equal numeros, numeros.uniq, "cada caja debe tener su propio numero_recepcion"
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
end
