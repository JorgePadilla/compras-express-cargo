require "test_helper"

# C32-01 · El historial de manifiestos. Yusef: *"aquí está el historial del
# año"* · *"haces el de cheque, porque yo ocupo marcar cuáles están enviados,
# cuáles están en aduana"* · *"un buscador que le doy CER y me salgan todos los
# que traen CER"* · *"solo nos incluía hasta tres meses"*. Jorge, 2026-10-15:
# una sección nueva con filtros, y al entrar, todos los estados marcados.
class HistorialManifiestosTest < ActionDispatch::IntegrationTest
  setup do
    @creado = manifiestos(:creado)
    @enviado = manifiestos(:enviado)
    @creado.update!(tipo_envio_ids: [ tipo_envios(:cer).id ])
    @enviado.update!(tipo_envio_ids: [ tipo_envios(:cem).id ], empresa_manifiesto: empresa_manifiestos(:pronto))
  end

  def ingresar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  def numeros = css_select("tr[data-manifiesto]").map { |tr| tr["data-manifiesto"] }

  # ── Quién entra ─────────────────────────────────────────────────────────

  test "entran Miami y los jefes de San Pedro; el cajero no" do
    [ users(:digitador), users(:supervisor_prefactura) ].each do |u|
      ingresar(u)
      get historial_manifiestos_path
      assert_response :success, u.rol
    end

    ingresar(users(:cajero))
    get historial_manifiestos_path
    assert_redirected_to root_path
  end

  test "está en el menú, pegado a Manifiestos" do
    ingresar(users(:digitador))
    get manifiestos_path
    assert_select "a[href=?]", historial_manifiestos_path, text: /Historial de manifiestos/
  end

  # ── Los filtros ─────────────────────────────────────────────────────────

  test "al entrar vienen todos los estados marcados y salen todos los manifiestos" do
    ingresar(users(:digitador))
    get historial_manifiestos_path

    HistorialManifiestosController::ESTADOS.each do |valor, _|
      assert_select "input[name='estados[]'][value=?][checked]", valor
    end
    assert_includes numeros, @creado.numero
    assert_includes numeros, @enviado.numero
  end

  test "los estados se marcan de a varios" do
    recibido = Manifiesto.create!(tipo_envios: [ tipo_envios(:cer) ], estado: "recibido")
    ingresar(users(:digitador))

    get historial_manifiestos_path(estados: %w[enviado recibido])

    assert_equal [ recibido.numero, @enviado.numero ].sort, numeros.sort
    assert_select "input[name='estados[]'][value='creado']:not([checked])"
  end

  test "«Terminado de Prefacturar» es un estado aparte: no sale en «Recibido»" do
    terminado = Manifiesto.create!(tipo_envios: [ tipo_envios(:cer) ], estado: "recibido")
    Paquete.create!(tracking: "1ZHISTORIAL0001", cliente: clientes(:juan), estado: "en_aduana",
                    manifiesto: terminado, tipo_envio: tipo_envios(:cer))
           .update_columns(pre_factura_id: pre_facturas(:borrador_juan).id)
    ingresar(users(:digitador))

    get historial_manifiestos_path(estados: %w[recibido])
    assert_not_includes numeros, terminado.numero

    get historial_manifiestos_path(estados: %w[terminado])
    assert_equal [ terminado.numero ], numeros
  end

  test "por empresa, por tipo de envío y oficial o interno" do
    ingresar(users(:digitador))

    get historial_manifiestos_path(empresa_manifiesto_id: empresa_manifiestos(:pronto).id)
    assert_equal [ @enviado.numero ], numeros

    get historial_manifiestos_path(tipo_envio_ids: [ tipo_envios(:cer).id ])
    assert_equal [ @creado.numero ], numeros

    get historial_manifiestos_path(tipo: "interno")
    assert_empty numeros
  end

  # *"Escribo esto y me agarra los dos, yo quiero éste exclusivamente."*
  test "el buscador es exacto: número, guía o tipo de envío, entero" do
    @enviado.guias.create!(numero: "286441-1")
    ingresar(users(:digitador))

    get historial_manifiestos_path(q: @creado.numero.downcase)
    assert_equal [ @creado.numero ], numeros

    get historial_manifiestos_path(q: "MA-00000")
    assert_empty numeros, "un pedazo del número no trae nada"

    get historial_manifiestos_path(q: "286441-1")
    assert_equal [ @enviado.numero ], numeros

    get historial_manifiestos_path(q: tipo_envios(:cer).codigo.downcase)
    assert_equal [ @creado.numero ], numeros
  end

  # *"Solo nos incluía hasta tres meses; si yo quiero ver de tres meses a doce,
  # le doy click, y si quiero ver de más de doce meses, le doy a tanto."*
  test "la ventana: 3 meses por defecto, 3-12 y más de un año a pedido, o desde y hasta" do
    @creado.update_columns(created_at: 5.months.ago)
    @enviado.update_columns(created_at: 2.years.ago)
    ingresar(users(:digitador))

    get historial_manifiestos_path
    assert_empty numeros

    get historial_manifiestos_path(incluir_3_12_meses: "1")
    assert_equal [ @creado.numero ], numeros

    get historial_manifiestos_path(incluir_mas_1_ano: "1")
    assert_equal [ @creado.numero, @enviado.numero ].sort, numeros.sort

    get historial_manifiestos_path(desde: 3.years.ago.to_date.iso8601, hasta: 1.year.ago.to_date.iso8601)
    assert_equal [ @enviado.numero ], numeros
  end

  test "la lista dice creado, enviado, recibido, a dónde va y cuándo empezó a pre-facturarse" do
    @enviado.update_columns(estado: "recibido", fecha_enviado: Time.zone.parse("2026-10-01 10:00"), expedido_por: "MI",
                            fecha_aduana: Time.zone.parse("2026-10-06 14:00"), recibido_hn_por: "SP")
    @enviado.update!(sucursal_entrega_ids: [ sucursales(:zeron_sps).id ])
    Paquete.create!(tracking: "1ZHISTORIAL0002", cliente: clientes(:juan), estado: "en_aduana",
                    manifiesto: @enviado, tipo_envio: tipo_envios(:cem))
           .update_columns(pre_factura_id: pre_facturas(:borrador_juan).id)
    ingresar(users(:digitador))

    get historial_manifiestos_path

    assert_select "tr[data-manifiesto=?]", @enviado.numero do
      assert_select "td", text: %r{01/10/2026 · MI}
      assert_select "td", text: %r{06/10/2026 · SP}
      assert_select "td", text: sucursales(:zeron_sps).nombre
      assert_select "td", text: pre_facturas(:borrador_juan).created_at.strftime("%d/%m/%Y")
    end
  end
end
