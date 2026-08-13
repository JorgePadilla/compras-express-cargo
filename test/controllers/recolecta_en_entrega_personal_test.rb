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
        recolecta_instrucciones: "A 10 minutos de la bodega, preguntar en recepción."
      )
    }

    p = Paquete.order(:id).last
    assert p.recolecta_solicitada?
    assert_equal "Manuel Quiñones", p.recolecta_contacto
    assert_equal "9999-9999", p.recolecta_telefono
    assert_equal "9:30 a. m. a 6:00 p. m.", p.recolecta_horario
    assert_match(/recepci[oó]n/, p.recolecta_instrucciones)
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
