require "test_helper"

# C21-08 · «Que un CRUD para todo, para todo lo del manifiesto».
#
# Yusef, 2026-08-29, después de explicar el manifiesto entero:
#
#   > "Si vos creás una [pantalla] donde yo pueda crear las empresas, los tipos
#   >  de envío que manejamos, la empresa que lo envía, qué consignatario somos
#   >  nosotros… que pueda yo crear estos, las cajas, los tamaños de las cajas,
#   >  en un solo [lugar]."
#   > "Como un portal, por decirte algo… pero que todo esté ahí, porque así uno
#   >  no tiene que andar buscando."
#
# Dos de los cuatro catálogos existían de nombre y estaban **vacíos por dentro**
# —`Consignatario` y `TamanoCaja`: tablas sin filas, sin pantalla y sin
# asociaciones—, uno solo guardaba el nombre (`EmpresaManifiesto`) y el cuarto
# —el tipo de envío del PROVEEDOR— no existía en ninguna forma.
class CatalogosManifiestoTest < ActionDispatch::IntegrationTest
  setup do
    @miami = users(:digitador)
    ingresar(@miami)
  end

  test "el portal muestra los cuatro catálogos en una sola pantalla" do
    get catalogos_manifiesto_path

    assert_response :success
    assert_select "a", text: /Empresas proveedoras/
    assert_select "a", text: /Tipo de envío del proveedor/
    assert_select "a", text: /Consignatarios/
    assert_select "a", text: /Tamaños de caja/
  end

  test "cada solapa abre la suya, y una inventada cae en la primera" do
    CatalogosManifiestoController::SOLAPAS.each do |solapa|
      get catalogos_manifiesto_path(tab: solapa)
      assert_response :success
    end

    get catalogos_manifiesto_path(tab: "loquesea")
    assert_response :success
  end

  # El pedido es poder DELEGAR: *"andate al área donde dice empresa, agregame
  # esta empresa que voy a usar"*. Un portal admin-only cumpliría la letra y
  # fallaría el propósito, así que lo abre el supervisor de Miami.
  test "el equipo de Miami entra sin ser admin" do
    assert_not @miami.admin?

    get catalogos_manifiesto_path

    assert_response :success
  end

  test "quien no es de Miami no entra" do
    ingresar(users(:cajero))

    get catalogos_manifiesto_path

    assert_redirected_to root_path
  end

  # ── Los cuatro CRUD ────────────────────────────────────────────────────
  #
  # Todos vuelven al portal **con su solapa puesta**: volver a un índice propio
  # sería mandarlo a andar buscando de nuevo.

  test "crear una empresa proveedora con su teléfono y su encargado" do
    assert_difference "EmpresaManifiesto.count", 1 do
      post empresas_manifiesto_index_path, params: { empresa_manifiesto: {
        nombre: "CAROLINA CARGO", direccion: "2003 NW 79 Ave, Doral",
        telefono: "305-848-0990", encargado: "Michelle", activo: "1"
      } }
    end

    assert_redirected_to catalogos_manifiesto_path(tab: "empresas")
    empresa = EmpresaManifiesto.find_by!(nombre: "CAROLINA CARGO")
    assert_equal "305-848-0990", empresa.telefono
    assert_equal "Michelle", empresa.encargado,
                 "el teléfono y la persona encargada salen impresos en el manifiesto"
  end

  test "crear un tipo de envío del proveedor, que no es el nuestro" do
    assert_difference "TipoEnvioProveedor.count", 1 do
      post tipos_envio_proveedor_index_path,
           params: { tipo_envio_proveedor: { nombre: "AEREO EXPRESS", activo: "1" } }
    end

    assert_redirected_to catalogos_manifiesto_path(tab: "tipos_proveedor")
    assert TipoEnvioProveedor.exists?(nombre: "AEREO EXPRESS")
    assert_not TipoEnvio.exists?(nombre: "AEREO EXPRESS"),
               "el del proveedor no puede terminar en nuestro catálogo: es la confusión que Yusef reclamó"
  end

  test "crear un consignatario" do
    assert_difference "Consignatario.count", 1 do
      post consignatarios_path, params: { consignatario: {
        nombre: "CORPORACION KARSAM", identidad: "215", direccion: "San Pedro Sula", activo: "1"
      } }
    end

    assert_redirected_to catalogos_manifiesto_path(tab: "consignatarios")
  end

  test "crear un tamaño de caja con sus medidas" do
    assert_difference "TamanoCaja.count", 1 do
      post tamanos_caja_index_path, params: { tamano_caja: {
        nombre: "Mini D", alto: "46", largo: "43", ancho: "50", activo: "1"
      } }
    end

    assert_redirected_to catalogos_manifiesto_path(tab: "tamanos")
    assert TamanoCaja.find_by!(nombre: "Mini D").medidas_completas?
  end

  # «Especificar» es uno de los diez tamaños de la pantalla vieja y no tiene
  # medidas: es el que se mide a mano.
  test "un tamaño sin medidas se guarda igual — es «Especificar»" do
    assert_difference "TamanoCaja.count", 1 do
      post tamanos_caja_index_path, params: { tamano_caja: { nombre: "Especificar", activo: "1" } }
    end

    assert_not TamanoCaja.find_by!(nombre: "Especificar").medidas_completas?
  end

  test "editar un tamaño vuelve al portal, en su solapa" do
    tamano = TamanoCaja.create!(nombre: "EH", alto: 40, largo: 40, ancho: 40)

    patch tamanos_caja_path(tamano), params: { tamano_caja: { nombre: "EH cortada", alto: "30" } }

    assert_redirected_to catalogos_manifiesto_path(tab: "tamanos")
    assert_equal "EH cortada", tamano.reload.nombre
    assert_equal 30, tamano.alto.to_i
  end

  test "un nombre repetido no pasa" do
    TamanoCaja.create!(nombre: "Mini D Doble")

    assert_no_difference "TamanoCaja.count" do
      post tamanos_caja_index_path, params: { tamano_caja: { nombre: "mini d doble" } }
    end

    assert_response :unprocessable_entity
  end

  private

  def ingresar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end
end
