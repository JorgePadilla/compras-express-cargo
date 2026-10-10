require "test_helper"

# PR-P.5 · `/pre-factura/auditar`, por el controller: la hoja como puerta, el
# JSON de cada escaneo y de F9.
class AuditarPreFacturaControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:supervisor_prefactura)
    @cliente = clientes(:juan)
    @cer = tipo_envios(:cer)
    @manifiesto = manifiestos(:enviado)
    @manifiesto.update_columns(estado: "en_aduana")
    Tarifa.delete_all
    Tarifa.create!(tipo_envio: @cer, precio_libra: 4.50, moneda: "USD")

    @cajas = 2.times.map do
      Paquete.create!(tracking: "1ZCTL#{SecureRandom.hex(5).upcase}", cliente: @cliente, tipo_envio: @cer,
                      sucursal_recepcion: sucursales(:miami), manifiesto: @manifiesto,
                      estado: "en_aduana", descripcion: "Zapatos", peso: 2)
    end
    @bulto, = MedirBulto.new(user: @user).guardar!(paquete_ids: @cajas.map(&:id), volumenes: [ { peso: "4", alto: "10", largo: "12", ancho: "14" } ])
    @qr = "MED #{@cajas.first.reload.tracking} 4.00 10x12x14"
  end

  # ── La puerta ──────────────────────────────────────────────────────────

  test "sin hoja lista, vuelve a la hoja" do
    ingresar(@user)
    get auditar_pre_factura_index_url
    assert_redirected_to hoja_de_preparacion_path

    post escanear_volumen_auditar_pre_factura_index_url, params: { codigo: @qr }, as: :json
    assert_equal "sin_hoja", response.parsed_body["resultado"]
  end

  test "Miami no entra" do
    ingresar(users(:digitador))
    get auditar_pre_factura_index_url
    assert_redirected_to root_path
  end

  test "con la hoja lista, la pantalla" do
    con_hoja
    get auditar_pre_factura_index_url

    assert_response :success
    assert_select "[data-controller~='auditar-pre-factura'][data-controller~='audio']"
    assert_select "#codigo_auditoria"
  end

  # ── El volumen ─────────────────────────────────────────────────────────

  test "el QR del volumen trae el cliente, los volúmenes, las cajas y las líneas" do
    con_hoja
    post escanear_volumen_auditar_pre_factura_index_url, params: { codigo: @qr }, as: :json
    data = response.parsed_body

    assert_equal "ok", data["resultado"]
    assert_equal @bulto.sesion, data["sesion"]
    assert_equal({ "codigo" => @cliente.codigo, "nombre" => @cliente.nombre_completo }, data["cliente"])
    assert_equal "1 volumen · 2 cajas", data["resumen"]
    assert_nil data["aviso_ndem"], "la etiqueta está al día"
    assert_equal 1, data["volumenes"].size
    assert_equal 4.0, data["volumenes"].first["peso"]
    assert data["volumenes"].first["pies3"].positive?
    assert_equal @cajas.map(&:id).sort, data["cajas"].map { |c| c["id"] }.sort
    assert data["lineas"]["items"].any? { |i| i["concepto"].include?("Volumen") || i["concepto"].include?("Flete") }
    assert data["lineas"]["total"].positive?
  end

  # Después de medir de nuevo, la etiqueta vieja «1de2» sigue resolviendo a la
  # tanda de hoy, que tiene un solo volumen.
  test "una etiqueta de una medición anterior avisa, y carga la tanda de hoy" do
    con_hoja
    post escanear_volumen_auditar_pre_factura_index_url, params: { codigo: "#{@qr} 1de2" }, as: :json
    data = response.parsed_body

    assert_equal "ok", data["resultado"]
    assert_equal @bulto.sesion, data["sesion"]
    assert_equal "Esta etiqueta es de una medición anterior: la tanda hoy tiene 1 volumen — reimprimí las etiquetas.",
                 data["aviso_ndem"]
  end

  test "ya pre-facturada: el rechazo trae el link para abrirla" do
    con_hoja
    pf = pre_facturas(:borrador_juan)
    @cajas.first.update_columns(pre_factura_id: pf.id)
    post escanear_volumen_auditar_pre_factura_index_url, params: { codigo: @qr }, as: :json

    assert_equal "ya_prefacturada", response.parsed_body["resultado"]
    assert_equal pre_factura_path(pf), response.parsed_body["pre_factura_url"]
  end

  # ── Las cajas ──────────────────────────────────────────────────────────

  test "la etiqueta de Miami: pertenece, ya escaneada, no corresponde" do
    con_hoja
    url = escanear_paquete_auditar_pre_factura_index_url

    post url, params: { codigo: @cajas.last.tracking, sesiones: [ @bulto.sesion ] }, as: :json
    assert_equal "pertenece", response.parsed_body["resultado"]
    assert_equal @cajas.last.id, response.parsed_body["caja_id"]

    post url, params: { codigo: @cajas.last.tracking, sesiones: [ @bulto.sesion ], escaneadas: [ @cajas.last.id ] }, as: :json
    assert_equal "ya_escaneada", response.parsed_body["resultado"]

    ajena = Paquete.create!(tracking: "1ZAJENA#{SecureRandom.hex(4).upcase}", cliente: clientes(:maria), tipo_envio: @cer,
                            estado: "en_aduana", descripcion: "x", peso: 1, sucursal_recepcion: sucursales(:miami))
    post url, params: { codigo: ajena.tracking, sesiones: [ @bulto.sesion ] }, as: :json
    assert_equal "no_corresponde", response.parsed_body["resultado"]
  end

  # ── F9 ─────────────────────────────────────────────────────────────────

  test "F9 con todas las cajas: la pre-factura, y a dónde ir a imprimir" do
    con_hoja(hora: "14:30", fecha: 1.day.from_now.to_date.iso8601)
    post guardar_auditar_pre_factura_index_url,
         params: { sesiones: [ @bulto.sesion ], escaneadas: @cajas.map(&:id) }, as: :json

    data = response.parsed_body
    assert data["ok"], data["mensaje"]
    pf = PreFactura.find_by!(numero: data["numero"])
    assert_equal 1.day.from_now.to_date, pf.notificar_at.to_date
    assert_equal [ 14, 30 ], [ pf.notificar_at.hour, pf.notificar_at.min ]
    assert data["imprimir_url"].present?
    assert_match(/El aviso sale el/, data["mensaje"])
  end

  # ── F8 (PR-P.6) ──────────────────────────────────────────────────────

  test "F8 guarda consolidando, sin aviso, y la etiqueta lleva la franja" do
    con_hoja
    post guardar_auditar_pre_factura_index_url,
         params: { sesiones: [ @bulto.sesion ], escaneadas: @cajas.map(&:id), modo: "consolidar" }, as: :json
    data = response.parsed_body

    assert data["ok"], data["mensaje"]
    assert_match(/consolidando/, data["mensaje"])
    pf = PreFactura.find_by!(numero: data["numero"])
    assert pf.consolidando_at.present?
    assert_nil pf.notificar_at

    get data["imprimir_url"]
    assert_includes response.body, "CONSOLIDANDO"
  end

  test "el volumen de una consolidando la reabre, con sus cajas ya auditadas" do
    # Otra carga del manifiesto sin pre-facturar: si no, después de F8 el
    # manifiesto ya no tiene nada pendiente y la hoja deja de estar lista.
    Paquete.create!(tracking: "1ZOTRA#{SecureRandom.hex(4).upcase}", cliente: @cliente, tipo_envio: @cer,
                    sucursal_recepcion: sucursales(:miami), manifiesto: @manifiesto,
                    estado: "en_aduana", descripcion: "x", peso: 1)
    con_hoja
    post guardar_auditar_pre_factura_index_url,
         params: { sesiones: [ @bulto.sesion ], escaneadas: @cajas.map(&:id), modo: "consolidar" }, as: :json
    pf = PreFactura.find_by!(numero: response.parsed_body["numero"])

    post escanear_volumen_auditar_pre_factura_index_url, params: { codigo: @qr }, as: :json
    data = response.parsed_body

    assert_equal "consolidando", data["resultado"]
    assert_equal({ "id" => pf.id, "numero" => pf.numero }, data["pre_factura"])
    assert_equal [ @bulto.sesion ], data["tandas"].map { |t| t["sesion"] }
    assert_equal @cajas.map(&:id).sort, data["escaneadas"].sort
    assert data["lineas"]["total"].positive?
  end

  test "F9 con cajas sin escanear: 422 y nada guardado" do
    con_hoja
    assert_no_difference "PreFactura.count" do
      post guardar_auditar_pre_factura_index_url,
           params: { sesiones: [ @bulto.sesion ], escaneadas: [ @cajas.first.id ] }, as: :json
    end
    assert_response :unprocessable_entity
    assert_match(/Faltan 1 caja/, response.parsed_body["mensaje"])
  end

  private

  def ingresar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  def con_hoja(hora: "07:30", fecha: Date.current.iso8601)
    ingresar(@user)
    patch hoja_de_preparacion_url, params: { hoja: { modo: "nuevas", tipo_envio_ids: [ @cer.id ],
                                                     manifiesto_ids: [ @manifiesto.id ], fecha: fecha, hora: hora } }
  end
end
