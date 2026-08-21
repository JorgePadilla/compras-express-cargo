require "test_helper"

# Que la pantalla de admin diga lo mismo que la del cliente.
#
# Jorge, 2026-08-20: *"revisá la parte de cliente y aplicale las reglas al
# admin"*. El portal comunica las tres reglas con su forma —agrupa los servicios
# en «con reempaque» y «sin reempaque», y el paso de consolidación **no existe**
# para los que no la permiten—. Admin tenía dos casillas sueltas.
class AdminPreAlertaReglasTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: {
      email_address: users(:admin).email_address, password: "password123"
    }
    @cer = tipo_envios(:cer)   # reempaca y consolida
    @cka = tipo_envios(:cka)   # ninguna de las dos, y un solo tracking
  end

  test "la pantalla de alta no ofrece elegir el reempaque" do
    get new_pre_alerta_url

    assert_response :success
    assert_no_match(/name="pre_alerta\[con_reempaque\]"/, response.body)
  end

  test "y dice de dónde sale" do
    get new_pre_alerta_url

    assert_match(/Reempaque/, response.body)
    assert_match(/lo reempaca el servicio|viaja tal como llega/, response.body)
  end

  test "cada servicio lleva sus reglas para que la pantalla reaccione" do
    # Sin esto el select no puede acomodar nada sin volver al servidor.
    get new_pre_alerta_url

    assert_match(/data-tipo-envio-id="#{@cka.id}"[^>]*data-consolidable="false"/, response.body)
    assert_match(/data-max-paquetes="1"/, response.body)
  end

  test "la pantalla sabe cuántos paquetes permite el servicio sugerido" do
    # `pre_alerta_editor_controller` ya sabía deshabilitar «Agregar Paquete»
    # (`maxPaquetesValue`, `isAtLimit`, `limitMessage`); esta vista nunca le pasó
    # el valor, así que el operario llenaba todo y el servidor lo rechazaba
    # después. /edit sí lo pasaba: la gemela otra vez.
    get new_pre_alerta_url

    assert_match(/data-pre-alerta-editor-max-paquetes-value=/, response.body)
  end

  test "el aviso del límite está en la pantalla" do
    get new_pre_alerta_url

    assert_match(/data-pre-alerta-editor-target="limitMessage"/, response.body)
  end

  test "la de editar tampoco ofrece el reempaque" do
    # La gemela, que es donde este repo se rompe siempre.
    pa = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: @cer,
                           titulo: "Para editar", estado: "pre_alerta")

    get edit_pre_alerta_url(pa)

    assert_response :success
    assert_no_match(/name="pre_alerta\[con_reempaque\]"/, response.body)
  end

  test "mandar el reempaque por parámetro no lo pisa" do
    # El `permit` ya no lo acepta, y el modelo lo deriva igual.
    post pre_alertas_url, params: { pre_alerta: {
      cliente_id: clientes(:juan).id, tipo_envio_id: @cka.id,
      titulo: "CKA con reempaque a la fuerza", con_reempaque: "1",
      pre_alerta_paquetes_attributes: { "0" => { tracking: "1ZREGLA0000001", descripcion: "x" } }
    } }

    assert_not PreAlerta.last.con_reempaque, "le ganó el parámetro al servicio"
  end

  test "consolidar un servicio que no consolida no guarda" do
    assert_no_difference "PreAlerta.count" do
      post pre_alertas_url, params: { pre_alerta: {
        cliente_id: clientes(:juan).id, tipo_envio_id: @cka.id,
        titulo: "CKA consolidada", consolidado: "1",
        pre_alerta_paquetes_attributes: { "0" => { tracking: "1ZREGLA0000002", descripcion: "x" } }
      } }
    end

    assert_response :unprocessable_entity
  end

  test "y el error dice por qué" do
    post pre_alertas_url, params: { pre_alerta: {
      cliente_id: clientes(:juan).id, tipo_envio_id: @cka.id,
      titulo: "CKA consolidada", consolidado: "1",
      pre_alerta_paquetes_attributes: { "0" => { tracking: "1ZREGLA0000003", descripcion: "x" } }
    } }

    assert_match(/no se consolida/, response.body)
  end
end
