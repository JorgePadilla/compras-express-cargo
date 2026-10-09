require "test_helper"
require "zip"

# C28-02 · El desglose de paquetes del manifiesto, **aparte** de la hoja que
# viaja con la carga. Yusef, el 2026-10-03: *"el listado sí va amarrado, pero
# no va en la impresión. Eso lo sacamos aparte"*. Y las dos puertas que pidió:
# *"donde yo le puedo imprimir eso, exportar Excel"* y *"en el filtro… buscarlo
# por manifiesto"*.
class ManifiestoListadoTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @manifiesto = manifiestos(:creado)
  end

  test "el listado sale, con la marca de uso interno y sin firmas" do
    paquete = paquetes(:disponible_entrega_juan)
    paquete.update!(manifiesto: @manifiesto, descripcion: "dos generadores")

    get listado_manifiesto_url(@manifiesto)

    assert_response :success
    assert_match(/Listado de paquetes #{@manifiesto.numero}/, response.body)
    assert_match(/NO SE ENTREGA AL TRANSPORTISTA/, response.body)
    assert_select "table.ls-t td", text: paquete.tracking
    assert_select "table.ls-t td", text: "dos generadores"
    assert_no_match(/Nombre y firma/i, response.body)
  end

  # C28-03 · Las cajas de un split comparten el número madre: sin el sufijo,
  # dos renglones iguales.
  test "las cajas de un split salen con su sufijo, no repetidas" do
    cajas = Paquete.crear_split!(
      attrs: { tracking: "1Z999LISTADO", cliente: clientes(:juan), sucursal: sucursales(:miami) },
      total_cajas: 2
    )
    cajas.each { |c| c.update!(manifiesto: @manifiesto) }
    madre = cajas.first.numero_recepcion

    get listado_manifiesto_url(@manifiesto)

    assert_select "table.ls-t td", text: "#{madre}-1"
    assert_select "table.ls-t td", text: "#{madre}-2"
  end

  # Se revisa abriendo la caja A y tachando lo de adentro: el orden es por
  # bulto, y lo que entró sin pistola va al final.
  test "va ordenado por bulto, y lo sin escanear al final" do
    b = @manifiesto.cajas.create!(alto: 10, largo: 10, ancho: 10, peso: 5)
    a = @manifiesto.cajas.create!(alto: 10, largo: 10, ancho: 10, peso: 5)
    # La primera que se creó es la A; se le pone el paquete que se creó último.
    a, b = [ a, b ].sort_by(&:letra)
    suelto = paquetes(:disponible_entrega_juan)
    suelto.update!(manifiesto: @manifiesto)
    en_b = Paquete.create!(tracking: "1Z999ENB", cliente: clientes(:juan), sucursal: sucursales(:miami),
                           manifiesto: @manifiesto, caja_manifiesto: b)
    en_a = Paquete.create!(tracking: "1Z999ENA", cliente: clientes(:juan), sucursal: sucursales(:miami),
                           manifiesto: @manifiesto, caja_manifiesto: a)

    get listado_manifiesto_url(@manifiesto)

    orden = [ en_a.tracking, en_b.tracking, suelto.tracking ].map { |t| response.body.index(t) }
    assert_equal orden.sort, orden, "esperaba A, después B, después el suelto"
    assert_match(/sin escanear/, response.body)
  end

  test "la pantalla del manifiesto ofrece imprimir el listado y el Excel" do
    paquetes(:disponible_entrega_juan).update!(manifiesto: @manifiesto)

    get manifiesto_url(@manifiesto)

    assert_select "a[href=?]", listado_manifiesto_path(@manifiesto, print: true, cerrar: 1)
    assert_select "a[href*='manifiesto=#{@manifiesto.numero}'][href*='.xlsx']"
  end

  test "el Excel trae solo los paquetes de ese manifiesto, y facturados incluidos" do
    adentro = paquetes(:disponible_entrega_juan)
    adentro.update!(manifiesto: @manifiesto)
    afuera = paquetes(:recibido)

    get export_paquetes_url(format: :xlsx, manifiesto: @manifiesto.numero,
                            incluir_facturados: 1, incluir_mas_1_ano: 1)

    assert_response :success
    hoja = hoja_del_xlsx(response.body)
    assert_includes hoja, adentro.tracking
    assert_not_includes hoja, afuera.tracking
  end

  test "/paquetes filtra por manifiesto, con el final del número alcanza" do
    adentro = paquetes(:disponible_entrega_juan)
    adentro.update!(manifiesto: @manifiesto)

    get paquetes_url, params: { manifiesto: @manifiesto.numero.last(6), incluir_mas_1_ano: "1" }

    assert_response :success
    assert_match(/#{Regexp.escape(adentro.tracking)}/, response.body)
    assert_no_match(/#{Regexp.escape(paquetes(:recibido).tracking)}/, response.body)
    assert_select "input#qf_manifiesto[value=?]", @manifiesto.numero.last(6)
  end

  private

  def hoja_del_xlsx(bytes)
    Zip::File.open_buffer(bytes) do |zip|
      partes = zip.glob("xl/{sharedStrings,worksheets/sheet1}.xml").map { |e| e.get_input_stream.read }
      return partes.join
    end
  end
end
