require "test_helper"

# PR-F1.3 · «Facturación SAR»: cargar y ver los CAI. Admin y nadie más.
class AutorizacionesSarControllerTest < ActionDispatch::IntegrationTest
  setup do
    @ficticia = autorizaciones_sar(:ficticia)
    entrar(users(:admin))
  end

  def entrar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  def datos(**cambios)
    { punto_de_emision_id: puntos_de_emision(:tgu).id, tipo_documento: "01", cai: "ABC123-DEF456",
      rango_inicio: 1, rango_fin: 2500, fecha_autorizacion: "2026-10-01",
      fecha_limite_emision: "2027-10-01" }.merge(cambios)
  end

  test "el listado muestra los puntos, las sucursales sin punto y los CAI con su rango completo" do
    puntos_de_emision(:sam).destroy!
    get autorizaciones_sar_url
    assert_response :success

    assert_select "td", text: "000-001"
    assert_select "td", text: /Sin punto de emisión/
    assert_select "a[href=?]", new_punto_de_emision_path(sucursal_id: sucursales(:san_manuel).id)
    assert_select "td", text: /000-001-01-00000001\s*000-001-01-00005000/
    assert_select "span", text: "Ficticia"
    assert_select "a[href=?]", autorizacion_sar_path(@ficticia)
  end

  test "Miami no aparece entre las sucursales que facturan" do
    get autorizaciones_sar_url
    assert_select "td", text: "Miami", count: 0
  end

  test "carga una autorización y anota quién la cargó" do
    assert_difference -> { AutorizacionSar.count } do
      post autorizaciones_sar_url, params: { autorizacion_sar: datos }
    end
    nueva = AutorizacionSar.order(:id).last
    assert_redirected_to autorizacion_sar_path(nueva)
    assert_equal users(:admin), nueva.cargada_por
    assert_equal "001-001-01", nueva.identificador
    assert_not nueva.ficticia?
  end

  test "ficticia no se puede cargar desde el formulario" do
    post autorizaciones_sar_url, params: { autorizacion_sar: datos(ficticia: "1") }
    assert_not AutorizacionSar.order(:id).last.ficticia?
  end

  test "un rango que se pisa vuelve al formulario con el error" do
    assert_no_difference -> { AutorizacionSar.count } do
      post autorizaciones_sar_url, params: { autorizacion_sar: datos(punto_de_emision_id: puntos_de_emision(:sps).id,
                                                                     rango_inicio: 4000, rango_fin: 6000) }
    end
    assert_response :unprocessable_entity
    assert_select "li", text: /se pisa/
  end

  test "la ficha muestra el rango completo y se puede editar mientras no se emitió" do
    get autorizacion_sar_url(@ficticia)
    assert_response :success
    assert_select "dd", text: /000-001-01-00000001 al 000-001-01-00005000/
    assert_select "a[href=?]", edit_autorizacion_sar_path(@ficticia)

    patch autorizacion_sar_url(@ficticia), params: { autorizacion_sar: { cai: "CAI-CORREGIDO" } }
    assert_redirected_to autorizacion_sar_path(@ficticia)
    assert_equal "CAI-CORREGIDO", @ficticia.reload.cai
  end

  test "con documentos emitidos no hay Editar, y el formulario no se abre" do
    correlativos_fiscales(:sps_factura).update!(ultimo: 10)

    get autorizacion_sar_url(@ficticia)
    assert_select "a[href=?]", edit_autorizacion_sar_path(@ficticia), count: 0
    assert_select "dd", text: /10 de 5,000/

    get edit_autorizacion_sar_url(@ficticia)
    assert_redirected_to autorizacion_sar_path(@ficticia)

    patch autorizacion_sar_url(@ficticia), params: { autorizacion_sar: { cai: "OTRO" } }
    assert_equal "FICTICIO-TEST-SPS-0001", @ficticia.reload.cai
  end

  test "el formulario trae el preview del número completo" do
    get new_autorizacion_sar_url
    assert_response :success
    assert_select "form[data-controller='rango-sar']"
    assert_select "option[data-prefijo='000-001']"
    assert_select "[data-rango-sar-target='desde']"
    assert_select "input[name='autorizacion_sar[ficticia]']", count: 0
  end

  # Configuración legal: ni desde /permisos se le concede a otro rol.
  test "la sección no se puede conceder desde /permisos" do
    assert_not PermisosDelSistema.editable?(:autorizaciones_sar)
    fila = PermisoDeRol.new(rol: "supervisor_caja", seccion: "autorizaciones_sar", permitido: true)
    assert_not fila.valid?

    get permisos_url
    assert_select "span", text: /es configuración legal, solo admin/

    # Y si alguien la mete por SQL, la pantalla de permisos no la ofrece y el
    # rol sigue afuera: lo que no es editable no se lee de la tabla.
    PermisoDeRol.insert_all([ { rol: "cajero", seccion: "autorizaciones_sar", permitido: true,
                                created_at: Time.current, updated_at: Time.current } ])
    delete session_url
    entrar(users(:cajero))
    get autorizaciones_sar_url
    assert_redirected_to root_path
  end

  test "quien no es admin no entra" do
    delete session_url
    entrar(users(:cajero))
    get autorizaciones_sar_url
    assert_redirected_to root_path

    assert_no_difference -> { AutorizacionSar.count } do
      post autorizaciones_sar_url, params: { autorizacion_sar: datos }
    end
  end
end
