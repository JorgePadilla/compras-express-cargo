require "test_helper"

# Las cajas se agregan igual en `/etiquetar` y en `/entrega_personal` — `PR-C7.17`.
#
# Jorge: *"veo que en etiqueta no me deja agregar más cajas como en entrega
# personal, ¿qué pasó?"*. No era otra UX: **el campo no existía**.
#
# `shared/_peso_medidas_calc` resolvía su `modo_cajas` con
# `x = :plantilla unless defined?(x)`, que no asigna nunca. Con `modo_cajas` en
# nil, la rama que pintaba el campo de cajas no corría, y
# `EtiquetarController#create` leía un campo ausente como "cero cajas": **nunca
# se creaba un split**. Desde `PR-C7.04` (12-ago) hasta que él lo reportó.
#
# El test que lo cuidaba era un system test, y CI corre `rails test`, que no
# incluye `test/system`. Estos son de integración: sí corren.
class CajasEnLasDosPantallasTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:digitador).email_address,
                                password: "password123" }
  end

  # ── Las dos pantallas rinden el mismo componente ──────────────────────────

  test "etiquetar trae el boton de agregar caja" do
    iniciar_etiquetado
    get etiquetar_url

    assert_response :success
    assert_select "[data-cajas-repetidor-target='lista']"
    assert_match(/Agregar caja/, response.body)
  end

  test "entrega personal trae el mismo boton" do
    get new_entrega_personal_url

    assert_response :success
    assert_select "[data-cajas-repetidor-target='lista']"
    assert_match(/Agregar caja/, response.body)
  end

  # El campo del modo plantilla se fue con él: si vuelve, volvieron las dos
  # fuentes para el mismo número que ya costaron el bug de PR-C6.31.
  test "ya no hay campo de cantidad de cajas en ninguna de las dos" do
    iniciar_etiquetado
    get etiquetar_url
    assert_no_match(/Cant\. Cajas/, response.body)

    get new_entrega_personal_url
    assert_no_match(/Cant\. Cajas/, response.body)
  end

  # ── Y las dos dividen igual ───────────────────────────────────────────────

  # Este es el que falla con el código de antes: creaba 1 paquete.
  test "etiquetar vuelve a dividir un tracking en varias cajas" do
    iniciar_etiquetado

    assert_difference "Paquete.count", 3 do
      post etiquetar_url, params: { paquete: {
        tracking: "1Z#{SecureRandom.hex(4)}", cliente_id: clientes(:juan).id,
        descripcion: "Tres cajas", peso: 5,
        cajas: { "1" => { peso: 5 }, "2" => { peso: 8 }, "3" => { peso: 2 } }
      } }
    end

    cajas = Paquete.order(:id).last(3)
    assert_equal [ 1, 2, 3 ], cajas.map(&:numero_caja).sort
    assert_equal 1, cajas.map(&:tracking).uniq.size, "las cajas de un split son un tracking"
    assert_equal 1, cajas.map(&:numero_recepcion).uniq.size
    assert_equal [ 2.0, 5.0, 8.0 ], cajas.map { |c| c.peso.to_f }.sort
  end

  test "entrega personal divide igual" do
    assert_difference "Paquete.count", 3 do
      post entrega_personal_index_url, params: { paquete: {
        cliente_id: clientes(:juan).id, tipo_envio_id: tipo_envios(:cer).id,
        sucursal_recepcion_id: sucursales(:miami).id,
        proveedor_id: proveedores(:driver_entrega).id, descripcion: "Tres cajas", peso: 5,
        cajas: { "1" => { peso: 5 }, "2" => { peso: 8 }, "3" => { peso: 2 } }
      } }
    end

    assert_equal 1, Paquete.order(:id).last(3).map(&:tracking).uniq.size
  end

  private

  def iniciar_etiquetado
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: tipo_envios(:cer).id,
                   sucursal_recepcion_id: sucursales(:miami).id }
  end
end
