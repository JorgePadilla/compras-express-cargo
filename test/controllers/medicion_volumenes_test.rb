require "test_helper"

# C30-12 · Los volúmenes medidos, con buscador. Yusef, 2026-10-09: *"¿ahora
# puedo de alguna manera ver los volúmenes de los paquetes que hemos medido?…
# que tenga el filtro por cliente o por warehouse, como un buscador"*.
class MedicionVolumenesTest < ActionDispatch::IntegrationTest
  setup do
    ingresar(users(:medidor))
    @juan_caja = caja("1ZVOLUMEN0000001", numero_recepcion: "SPS2610000901")
    @juan = tanda([ @juan_caja ], volumenes: 2)
    @otra_caja = caja("1ZVOLUMEN0000002", cliente: otro_cliente, numero_recepcion: "SPS2610000902")
    @otra = tanda([ @otra_caja ])
  end

  test "lista los volúmenes, con sus números, las cajas de la tanda y «1 de 2»" do
    get volumenes_medicion_index_path

    assert_response :success
    assert_select "tr#bulto_#{@juan.first.id}" do
      assert_select "td", text: "1 de 2"
      assert_select "td", text: /12\.0x10\.0x8\.0/
      assert_select "a", text: "SPS2610000901"
    end
    assert_select "tr#bulto_#{@juan.second.id} td", text: "2 de 2"
    assert_select "tr#bulto_#{@otra.first.id} td", text: "Único"
  end

  # Jorge, 2026-10-10: copiar el QR del volumen desde la lista. Tiene que ser el
  # mismo texto de la etiqueta, y Auditar tiene que reconocerlo como volumen.
  test "cada volumen trae para copiar el texto de su QR, el mismo de la etiqueta" do
    get volumenes_medicion_index_path

    assert_select "tr#bulto_#{@juan.first.id} [data-qr-del-volumen]" do |nodos|
      qr = nodos.first["data-clipboard-text-value"]
      assert_match(/\AMED /, qr)
      assert_match(/1de2\z/, qr)
      assert AuditoriaDeTanda.volumen?(qr), "Auditar lo reconoce como el QR de un volumen"
      assert_equal @juan_caja.id, Paquete.por_codigo_de_etiqueta(qr).first&.id, "y lleva a una caja de la tanda"
    end
    assert_select "tr#bulto_#{@otra.first.id} [data-qr-del-volumen]" do |nodos|
      assert_no_match(/de\d+\z/, nodos.first["data-clipboard-text-value"], "un volumen único no lleva «1de1»")
    end
  end

  # Jorge, 2026-10-10: *"la columna de etiqueta deberíamos de usar acciones"* y
  # *"¿le falta la paginación?"*.
  test "la columna es «Acciones», con reimprimir y copiar el QR como íconos" do
    get volumenes_medicion_index_path

    assert_select "th", text: "Acciones"
    assert_select "tr#bulto_#{@juan.first.id}" do
      assert_select "a[href=?][title=?][target=_blank]", etiqueta_bulto_medicion_path(@juan.first, print: true), "Reimprimir la etiqueta del volumen"
      assert_select "[data-qr-del-volumen] button[data-action='clipboard#copy'].w-7"
    end
  end

  test "pagina de a 25 como las demás listas, con el «Por página»" do
    24.times do |i|
      c = caja("1ZPAGINA#{i.to_s.rjust(8, '0')}", numero_recepcion: "SPSPAG#{i}")
      tanda([ c ])
    end # con los 3 del setup son 27

    get volumenes_medicion_index_path
    assert_select "tbody tr", 25
    assert_match(/Mostrando\s*<span[^>]*>\s*1&nbsp;–&nbsp;25/, response.body)
    assert_select "select option", text: "50"

    get volumenes_medicion_index_path, params: { page: 2 }
    assert_select "tbody tr", 2
  end

  test "busca por código de cliente" do
    get volumenes_medicion_index_path, params: { q: clientes(:juan).codigo }

    assert_select "tr#bulto_#{@juan.first.id}"
    assert_select "tr#bulto_#{@otra.first.id}", count: 0
  end

  test "busca por warehouse: trae la tanda entera de esa caja" do
    get volumenes_medicion_index_path, params: { q: "0902" }

    assert_select "tr#bulto_#{@otra.first.id}"
    assert_select "tr#bulto_#{@juan.first.id}", count: 0
  end

  test "busca con la pistola: el código de la etiqueta de una caja" do
    get volumenes_medicion_index_path, params: { q: @juan_caja.tracking }

    assert_select "tr#bulto_#{@juan.first.id}"
    assert_select "tr#bulto_#{@juan.second.id}"
    assert_select "tr#bulto_#{@otra.first.id}", count: 0
  end

  test "filtra los que ya están en una pre-factura, y una anulada no cuenta" do
    pf = PreFactura.create!(cliente: clientes(:juan), estado: "creado", creado_por: users(:admin))
    pf.pre_factura_items.create!(concepto: "Flete", subtotal: 10, origen: PreFacturaItem::ORIGENES.first, bulto: @juan.first)

    get volumenes_medicion_index_path, params: { estado: "en_pre_factura" }
    assert_select "tr#bulto_#{@juan.first.id} a", text: pf.numero
    assert_select "tr#bulto_#{@otra.first.id}", count: 0

    get volumenes_medicion_index_path, params: { estado: "sin_pre_factura" }
    assert_select "tr#bulto_#{@juan.first.id}", count: 0
    assert_select "tr#bulto_#{@juan.second.id}"

    pf.update_columns(estado: "anulado")
    get volumenes_medicion_index_path, params: { estado: "sin_pre_factura" }
    assert_select "tr#bulto_#{@juan.first.id} td", text: /Sin pre-factura/
  end

  test "una fecha mal escrita no rompe la pantalla" do
    get volumenes_medicion_index_path, params: { fecha_desde: "ayer", fecha_hasta: "2026-13-40" }

    assert_response :success
  end

  test "sin permiso de medición no se entra" do
    delete session_path
    ingresar(users(:digitador))

    get volumenes_medicion_index_path

    assert_redirected_to root_path
  end

  private

  def ingresar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  def caja(tracking, cliente: clientes(:juan), **extra)
    Paquete.create!(tracking: tracking, cliente: cliente, tipo_envio: tipo_envios(:cer),
                    sucursal_recepcion: sucursales(:miami), estado: "en_aduana",
                    descripcion: "Zapatos", peso: 2, **extra)
  end

  def tanda(cajas, volumenes: 1)
    sesion = SecureRandom.uuid
    cajas.each { |c| c.update_columns(medicion_sesion: sesion, medido_at: Time.current) }
    (1..volumenes).map do |i|
      Bulto.create!(cliente: cajas.first.cliente, user: users(:medidor), sesion: sesion, orden: i,
                    de_cuantos: volumenes, medido_at: Time.current, peso: 5, alto: 12, largo: 10, ancho: 8)
    end
  end

  def otro_cliente
    Cliente.where.not(id: clientes(:juan).id).first
  end
end
