require "test_helper"

# C26-02 · La estación de Medición, por JSON.
class MedicionTest < ActionDispatch::IntegrationTest
  setup do
    @medidor = users(:medidor)
    @medidor.update!(iniciales: "MD")
    ingresar(@medidor)
    @paquete = caja("1ZMEDIR00000001")
  end

  def ingresar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  def caja(tracking, estado: "en_aduana", cliente: clientes(:juan))
    Paquete.create!(tracking: tracking, cliente: cliente, tipo_envio: tipo_envios(:cer),
                    sucursal_recepcion: sucursales(:miami), estado: estado, descripcion: "Zapatos", peso: 2)
  end

  def escanear(codigo) = post(escanear_medicion_index_path, params: { codigo: codigo }, as: :json)
  def medir(paquete, peso: "12.5", alto: "10", largo: "12", ancho: "14")
    patch medir_medicion_path(paquete), params: { peso: peso, alto: alto, largo: largo, ancho: ancho }, as: :json
  end
  def json = JSON.parse(response.body)

  # ── Escanear ─────────────────────────────────────────────────────────────

  test "una caja recibida se encuentra por su tracking, y trae sus números" do
    escanear(@paquete.tracking)

    assert_equal "ok", json["resultado"]
    assert_equal @paquete.id, json["paquete"]["id"]
    assert_match(/Juan/, json["paquete"]["cliente"])
    assert_nil json["unir"], "Juan no está consolidando"
    assert_nil json["medicion_previa"]
  end

  test "lo que no se encuentra, lo dice" do
    escanear("NOEXISTE123")

    assert_equal "no_encontrado", json["resultado"]
  end

  test "una caja que todavía no se recibió no se mide: Recibir Carga primero" do
    p = caja("1ZNOLLEGO0000001", estado: "enviado_honduras")
    escanear(p.tracking)

    assert_equal "no_esta_en_honduras", json["resultado"]
    assert_match(/Recibir Carga/, json["mensaje"])
  end

  test "una caja ya en pre-factura no se mide: el peso se congeló ahí" do
    @paquete.update_columns(pre_factura_id: PreFactura.first.id)
    escanear(@paquete.tracking)

    assert_equal "en_pre_factura", json["resultado"]
  end

  test "una caja ya medida avisa quién y cuándo" do
    @paquete.update!(medido_at: Time.zone.parse("2026-09-06 10:22"), medido_por: "SP", alto: 10, largo: 12, ancho: 14)
    escanear(@paquete.tracking)

    assert_equal "ok", json["resultado"]
    assert_equal "SP", json["medicion_previa"]["por"]
    assert_match(/06\/09\/2026/, json["medicion_previa"]["fecha"])
  end

  # ── Unir ─────────────────────────────────────────────────────────────────

  test "una caja de un grupo consolidado trae cuántos faltan y cuáles" do
    pa, otra = grupo_de_dos(@paquete)
    escanear(@paquete.tracking)

    unir = json["unir"]
    assert_equal pa.numero_documento, unir["numero"]
    assert_equal [ 2, 1, 0 ], unir.values_at("total", "llegados", "medidos")
    assert_equal [ [ @paquete.tracking, "llegó, sin medir" ], [ otra, "no ha llegado" ] ],
                 unir["faltantes"].map { |f| f.values_at("tracking", "donde") }
    assert_not unir["completo"]
    assert_equal facturar_parcial_medicion_path(pa), unir["facturar_parcial_url"]
  end

  test "una caja de una pre-alerta ya facturada avisa, y se deja medir" do
    cerrada = pre_alertas(:finalizada)
    cerrada.pre_alerta_paquetes.create!(tracking: @paquete.tracking, descripcion: "Tarde", fecha: Date.current, paquete: @paquete)

    escanear(@paquete.tracking)
    assert_equal "pre_alerta_ya_facturada", json["resultado"]
    assert_match(/partir la pre-alerta/, json["mensaje"])

    medir(@paquete)
    assert_response :success
    assert_equal "medido", json["resultado"]
  end

  # ── Medir ────────────────────────────────────────────────────────────────

  test "medir escribe, sella con las iniciales del que entró, y devuelve el paquete al día" do
    medir(@paquete)

    assert_response :success
    assert_equal "medido", json["resultado"]
    assert_equal 12.5, json["paquete"]["peso"]
    assert_equal 10.5, json["paquete"]["peso_volumetrico"]
    assert_equal "MD", @paquete.reload.medido_por
  end

  test "medir el último del grupo lo declara completo" do
    pa, otra = grupo_de_dos(@paquete)
    p2 = llego(paquete_del_renglon(pa, otra))
    medir(@paquete)
    assert_equal "medido", json["resultado"], "todavía falta uno"

    medir(p2)
    assert_equal "grupo_completo", json["resultado"]
    assert_match(/2 de 2 medidos/, json["mensaje"])
    assert json["unir"]["completo"]
  end

  test "una medida en cero es 422 con el porqué" do
    medir(@paquete, peso: "0")

    assert_response :unprocessable_entity
    assert_match(/mayores que cero/, json["errores"].join)
    assert_nil @paquete.reload.medido_at
  end

  # ── Facturar lo que hay ──────────────────────────────────────────────────

  test "facturar parcial con PIN de un jefe sella la pre-alerta" do
    pa, _otra = grupo_de_dos(@paquete)
    medir(@paquete)
    jefe = users(:supervisor_prefactura)
    jefe.update!(pin: "1234", iniciales: "SP")

    post facturar_parcial_medicion_path(pa), params: { supervisor_id: jefe.id, pin: "1234", motivo: "no viene" }, as: :json

    assert_response :success
    assert_equal "SP", json["unir"]["parcial_autorizado"]["por"]
    assert_equal "SP", pa.reload.union_parcial_por
    assert @paquete.reload.listo_para_prefactura?
  end

  test "facturar parcial con PIN equivocado es 422 y no sella" do
    pa, _otra = grupo_de_dos(@paquete)
    jefe = users(:supervisor_prefactura)
    jefe.update!(pin: "1234")

    post facturar_parcial_medicion_path(pa), params: { supervisor_id: jefe.id, pin: "0000", motivo: "no viene" }, as: :json

    assert_response :unprocessable_entity
    assert_match(/pin/i, json["errores"].join)
    assert_nil pa.reload.union_parcial_at
  end

  # ── Quién entra ──────────────────────────────────────────────────────────

  test "el rol medición entra a su estación y a nada más" do
    get medicion_index_path
    assert_response :success

    [ paquetes_path, pre_alertas_path, clientes_path, tareas_path ].each do |ruta|
      get ruta
      assert_response :redirect, "#{ruta}: «no se les habilita nada más que eso»"
    end
  end

  test "la raíz lo manda a su estación" do
    get root_path
    assert_redirected_to medicion_index_path
  end

  test "Honduras entra; Miami no" do
    ingresar(users(:cajero))
    get medicion_index_path
    assert_response :success

    ingresar(users(:digitador))
    get medicion_index_path
    assert_redirected_to root_path
  end

  private

  # Una pre-alerta consolidada de Juan con dos renglones: esta caja (ya llegó)
  # y otra que sigue esperada.
  def grupo_de_dos(paquete)
    otra = "1ZFALTA000000001"
    pa = pre_alerta_consolidada(paquete.tracking, otra)
    # El renglón de esta caja creó un esperado; en la vida real Miami lo
    # convierte en el paquete de verdad. Acá lo vinculamos a mano.
    esperado = paquete_del_renglon(pa, paquete.tracking)
    pa.pre_alerta_paquetes.find_by(tracking: paquete.tracking).update_columns(paquete_id: paquete.id)
    esperado.destroy
    [ pa, otra ]
  end

  # Una pre-alerta consolidada nueva de Juan. Cada renglón crea su paquete
  # esperado (`pre_alerta_estado`); «llegar» es que Miami lo reciba y Honduras
  # lo escanee — acá, moverlo a `en_aduana`. Las de fixtures ya traen renglones
  # y corren los conteos; y vaciar una la borra por callback.
  def pre_alerta_consolidada(*trackings)
    pa = PreAlerta.create!(numero_documento: "PA-T#{SecureRandom.hex(3).upcase}", cliente: clientes(:juan),
                           tipo_envio: tipo_envios(:aereo), consolidado: true, con_reempaque: true,
                           estado: "pre_alerta", titulo: "Consolidado de prueba",
                           creado_por_tipo: "usuario", creado_por_id: users(:admin).id)
    trackings.each { |t| pa.pre_alerta_paquetes.create!(tracking: t, descripcion: "Bulto #{t.last(3)}", fecha: Date.current) }
    pa
  end

  def paquete_del_renglon(pa, tracking)
    pa.pre_alerta_paquetes.find_by(tracking: tracking).paquete
  end

  def llego(paquete)
    paquete.update_columns(estado: "en_aduana")
    paquete.reload
  end

  # ── C26-04 · La etiqueta ─────────────────────────────────────────────────

  test "medir devuelve la URL de la etiqueta, y la etiqueta existe solo después de medir" do
    get etiqueta_medicion_path(@paquete)
    assert_response :not_found

    medir(@paquete)
    assert_match(%r{/medicion/#{@paquete.id}/etiqueta}, json["paquete"]["etiqueta_url"])

    get etiqueta_medicion_path(@paquete)
    assert_response :success
    assert_match(%r{class="codigo"[^>]*>#{@paquete.reload.numero_recepcion} · MD<}, response.body, "el código y quién midió")
    assert_match(/VLBS<\/span> 10\.50/, response.body)
    assert_match(/PIES³ 0\.97/, response.body)
    # El QR va dentro del SVG; su texto se afirma por el helper que lo arma.
    assert_equal "MED #{@paquete.numero_recepcion} 12.50 10x12x14", ApplicationController.helpers.etiqueta_qr_medicion(@paquete)
  end
end
