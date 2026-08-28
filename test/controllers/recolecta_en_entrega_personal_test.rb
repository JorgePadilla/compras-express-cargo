require "test_helper"

# A7-22 / A7-23: la recolecta vive dentro de Entrega Personal.
#
# Yusef la definió el 2026-08-12 con la frase más limpia que ha dado del módulo:
#
#   > "**La recolecta es como una prealerta de una entrega personal.**"
#   > "Acá en la entrega personal le podés dar una opción que diga que va a ser
#   >  una recolecta. **Antes de proveedores**."
#
# La diferencia con una entrega personal normal es que todavía no hay carga: hay
# que ir a traerla. Por eso los pesos son aproximados y hacen falta los datos de
# la visita.
class RecolectaEnEntregaPersonalTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
  end

  test "el switch de recolecta sale en la pantalla, antes de proveedor" do
    get new_entrega_personal_url

    assert_response :success
    assert_match "recolecta_solicitada", response.body
    assert_match(/por qui[eé]n preguntar/i, response.body)
    assert_match(/horario/i, response.body)

    posicion_recolecta = response.body.index("recolecta_solicitada")
    posicion_proveedor = response.body.index('name="paquete[proveedor_id]"')
    assert posicion_proveedor.nil? || posicion_recolecta < posicion_proveedor,
           "la recolecta tiene que ir antes de proveedor"
  end

  test "guarda los datos de la visita" do
    post entrega_personal_index_url, params: {
      paquete: attrs.merge(
        recolecta_solicitada: "1",
        recolecta_contacto: "Manuel Quiñones",
        recolecta_telefono: "9999-9999",
        recolecta_horario: "9:30 a. m. a 6:00 p. m.",
        recolecta_direccion: "Col. Jardines del Valle, 4 calle, bodega azul",
        recolecta_instrucciones: "Preguntar en recepción."
      )
    }

    p = Paquete.order(:id).last
    assert p.recolecta_solicitada?
    assert_equal "Manuel Quiñones", p.recolecta_contacto
    assert_equal "9999-9999", p.recolecta_telefono
    assert_equal "9:30 a. m. a 6:00 p. m.", p.recolecta_horario
    assert_match(/bodega azul/, p.recolecta_direccion)
    assert_match(/recepci[oó]n/, p.recolecta_instrucciones)
  end

  # C19-03. Yusef: "lo único que hace falta es que pongamos un campo que diga
  # dirección. Dirección de la recolecta". Y el hallazgo al costado: los datos
  # de la visita se guardaban y no se mostraban en ninguna pantalla.
  test "la direccion sale en el formulario, y la ficha muestra los datos de la visita" do
    get new_entrega_personal_url
    assert_match(/direcci[oó]n de la recolecta/i, response.body)

    post entrega_personal_index_url, params: {
      paquete: attrs.merge(
        recolecta_solicitada: "1",
        recolecta_direccion: "Col. Jardines del Valle, 4 calle, bodega azul",
        recolecta_contacto: "Manuel Quiñones"
      )
    }

    get paquete_url(Paquete.order(:id).last)
    assert_response :success
    assert_match "Datos de la Recolecta", response.body
    assert_match "bodega azul", response.body
    assert_match "Manuel Quiñones", response.body
  end

  test "la direccion se puede corregir despues desde /paquetes" do
    post entrega_personal_index_url, params: {
      paquete: attrs.merge(recolecta_solicitada: "1", recolecta_direccion: "La vieja")
    }
    p = Paquete.order(:id).last

    # Corregir es de EDIT_ROLES; el digitador de arriba no puede.
    delete session_url
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }

    patch paquete_url(p), params: { paquete: { recolecta_direccion: "La corregida" } }
    assert_equal "La corregida", p.reload.recolecta_direccion
  end

  # El bug que destapó meter la recolecta adentro de Entrega Personal: el
  # proveedor sigue siendo de tipo entrega_personal, así que la regla de EP
  # ganaba por orden de callback y la recolecta salía con tracking EP.
  test "una recolecta lleva tracking RC, no EP" do
    post entrega_personal_index_url, params: {
      paquete: attrs.merge(recolecta_solicitada: "1")
    }

    tracking = Paquete.order(:id).last.tracking
    assert_match(/\ARC-/, tracking, "salió con tracking de entrega personal: #{tracking}")
  end

  test "sin el switch sigue siendo entrega personal" do
    post entrega_personal_index_url, params: { paquete: attrs }

    assert_match(/\AEP-/, Paquete.order(:id).last.tracking)
  end

  test "el monto sale de la tarifa por zona" do
    tarifa = tarifas_recolecta(:la_lima_lps)

    post entrega_personal_index_url, params: {
      paquete: attrs.merge(recolecta_solicitada: "1", tarifa_recolecta_id: tarifa.id)
    }

    p = Paquete.order(:id).last
    assert_equal tarifa.monto.to_f, p.recolecta_monto.to_f
    assert_equal tarifa.moneda, p.recolecta_moneda
  end

  private

  def attrs
    {
      cliente_id: clientes(:juan).id,
      tipo_envio_id: tipo_envios(:cer).id,
      sucursal_id: sucursales(:miami).id,
      proveedor_id: proveedores(:driver_entrega).id,
      descripcion: "Carga por recolectar",
      peso: 200
    }
  end
end
