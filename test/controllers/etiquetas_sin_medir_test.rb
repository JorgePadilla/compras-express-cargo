require "test_helper"

# Yusef, 2026-08-18, en la llamada con la pantalla compartida:
#
#   > *"En etiquetar casi nunca medimos y pesamos."*
#   > *"Cuando la cantidad de cajas guardadas sea cero, que pregunte cuántas
#   >  son."*
#
# Lo repitió tres veces, la última al despedirse: *"acordate, no se te olvide
# corregir que si sale cero aquí, pregunte cuántas etiquetas"*.
#
# **Tres etiquetas son tres cajas**, no tres copias del mismo papel: el flete se
# cobra por caja, el Warehouse Receipt cuenta piezas y cada etiqueta lleva su
# `1/3`. Un envío de tres cajas grabado como un bulto se cobra mal.
class EtiquetasSinMedirTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: {
      email_address: users(:digitador).email_address, password: "password123"
    }
    post iniciar_sesion_etiquetar_url, params: {
      tipo_envio_id: tipo_envios(:cer).id, sucursal_recepcion_id: sucursales(:miami).id
    }
  end

  test "tres etiquetas graban tres cajas" do
    assert_difference "Paquete.count", 3 do
      post etiquetar_url, params: { print: "true", etiquetas: "3",
                                    paquete: datos("1Z999SINMEDIR001") }
    end

    cajas = Paquete.where(tracking: "1Z999SINMEDIR001").order(:numero_caja)
    assert_equal [ 1, 2, 3 ], cajas.map(&:numero_caja)
    assert_equal [ 3 ], cajas.map(&:cantidad_paquetes).uniq
    assert_equal 1, cajas.map(&:numero_recepcion).uniq.size, "no comparten el número madre"
    assert cajas.first.numero_recepcion.present?
  end

  test "una etiqueta es un solo bulto, como siempre" do
    assert_difference "Paquete.count", 1 do
      post etiquetar_url, params: { print: "true", etiquetas: "1",
                                    paquete: datos("1Z999SINMEDIR002") }
    end

    assert_nil Paquete.find_by(tracking: "1Z999SINMEDIR002").numero_caja
  end

  test "sin el parametro tampoco cambia nada" do
    # Guardar a secas —sin imprimir— no pregunta nada y sigue grabando un bulto.
    assert_difference "Paquete.count", 1 do
      post etiquetar_url, params: { paquete: datos("1Z999SINMEDIR003") }
    end
  end

  test "un numero imposible no graba nada" do
    # La pistola dispara Enter y el campo es numérico: un dedo de más grabaría
    # cientos de paquetes y mandaría cientos de etiquetas a la impresora.
    assert_no_difference "Paquete.count" do
      post etiquetar_url, params: { print: "true", etiquetas: "500",
                                    paquete: datos("1Z999SINMEDIR004") }
    end

    assert_response :unprocessable_entity
    assert_match(/1 a 99/, flash[:alert].to_s)
  end

  test "cero tampoco" do
    assert_no_difference "Paquete.count" do
      post etiquetar_url, params: { print: "true", etiquetas: "0",
                                    paquete: datos("1Z999SINMEDIR005") }
    end

    assert_response :unprocessable_entity
  end

  test "si midio una caja, la caja manda y no se pregunta nada" do
    # La condición que separa esto del modal que se quitó en `PR-C6.18b`: si hay
    # aunque sea una caja cargada, ella es la fuente. Nunca hay dos.
    assert_difference "Paquete.count", 1 do
      post etiquetar_url, params: {
        print: "true", etiquetas: "3",
        paquete: datos("1Z999SINMEDIR006").merge(cajas: { "1" => { peso: 22 } })
      }
    end

    assert_equal 22.0, Paquete.find_by(tracking: "1Z999SINMEDIR006").peso.to_f
  end

  test "con pre-alerta, la Caja 1 es el paquete esperado" do
    # El caso exacto que hizo en la llamada, y la intersección de lo de ayer
    # (`PR-C7.20`) con lo de hoy: escanear un tracking pre-alertado y pedir dos
    # etiquetas tiene que dar **dos** registros, no tres.
    pa = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                           titulo: "La de la llamada", estado: "pre_alerta")
    pap = pa.pre_alerta_paquetes.create!(tracking: "1Z999SINMEDIR007", descripcion: "Lo que viene")
    esperado = pap.paquete

    post etiquetar_url, params: { print: "true", etiquetas: "2",
                                  paquete: datos("1Z999SINMEDIR007") }

    cajas = Paquete.where(tracking: "1Z999SINMEDIR007").order(:numero_caja)
    assert_equal 2, cajas.size, "quedó un fantasma al lado de las cajas"
    assert_equal esperado.id, cajas.first.id
    assert_equal cajas.first.id, pap.reload.paquete_id
  end

  test "el formulario no tiene ningun otro campo que declare cantidad" do
    # La causa raíz de `PR-C6.31`: dos campos con el mismo `name`, ganaba el
    # último y el split se caía en silencio. El campo del modal se llama
    # `etiquetas` y va suelto, fuera de `paquete[...]`, justamente para que no
    # tenga con quién chocar.
    get etiquetar_url

    assert_response :success
    assert_no_match(/name="paquete\[cantidad_paquetes\]"/, response.body)
    assert_no_match(/name="etiquetas"/, response.body,
                    "el campo de la cantidad se pinta en el HTML: lo arma el JS al confirmar")
  end

  private

  def datos(tracking)
    { tracking: tracking, cliente_id: clientes(:juan).id, descripcion: "Sin medir", peso: 10 }
  end
end
