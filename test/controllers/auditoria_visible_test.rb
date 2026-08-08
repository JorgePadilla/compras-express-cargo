require "test_helper"

# PR-C6.15: mostrar lo que `paper_trail` ya venía guardando.
#
# Yusef, revisando un paquete: "auditar quién... en este no, fíjate, pero en
# otros campos sí. No sé si es que se lo quitó o no había".
#
# Tenía razón a medias, y el doc lo diagnosticó al revés: decía que faltaba
# extender `paper_trail` más allá de `Paquete`. **La captura no era el
# problema** — `has_paper_trail` está en 41 modelos. Lo que faltaba era verlo.
#
# Lo único con "quién" visible eran los cambios de estado, que llevan su propia
# columna `fecha_<estado>_by_user_id`. Por eso unos campos sí y otros no.
class AuditoriaVisibleTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @paquete = paquetes(:recibido)
  end

  test "el detalle muestra quien cambio que y cuando" do
    patch paquete_url(@paquete), params: { paquete: { descripcion: "contenido corregido" } }

    get paquete_url(@paquete)

    assert_match(/Historial de cambios/, response.body)
    assert_match @user.nombre, response.body
    assert_match "contenido corregido", response.body
  end

  test "muestra el valor viejo y el nuevo" do
    @paquete.update!(descripcion: "lo de antes")
    patch paquete_url(@paquete), params: { paquete: { descripcion: "lo de ahora" } }

    get paquete_url(@paquete)

    assert_match "lo de antes", response.body
    assert_match "lo de ahora", response.body
  end

  test "los ids se resuelven a nombres" do
    # Un `tipo_envio_id: 4 → 7` no le dice nada a nadie.
    #
    # Se busca DENTRO de la tabla de auditoría: el nombre del tipo de envío
    # sale en media página, así que buscarlo en `response.body` pasaba aunque
    # el historial mostrara el id crudo. Primer intento sin dientes.
    patch paquete_url(@paquete), params: { paquete: { tipo_envio_id: tipo_envios(:ckm).id } }

    get paquete_url(@paquete)
    tabla = response.body[/data-tabla="auditoria".*?<\/table>/m].to_s

    assert_match tipo_envios(:ckm).nombre, tabla
    assert_no_match(/tipo_envio_id/, tabla)
  end

  test "los campos de ruido no ensucian el historial" do
    # `updated_at` cambia en cada guardado y no aporta nada; `peso_cobrar` y
    # `peso_volumetrico` son derivados del peso, que sí se muestra.
    patch paquete_url(@paquete), params: { paquete: { peso: 42 } }

    get paquete_url(@paquete)
    fila = response.body[/data-tabla="auditoria".*?<\/table>/m].to_s

    assert_match(/Peso/, fila)
    assert_no_match(/Updated at/, fila)
    assert_no_match(/Peso volumetrico|Peso cobrar/i, fila)
  end

  test "un paquete sin cambios no muestra la seccion vacia" do
    PaperTrail::Version.where(item_type: "Paquete", item_id: @paquete.id).delete_all

    get paquete_url(@paquete)

    assert_no_match(/Historial de cambios/, response.body)
  end

  test "un cambio sin usuario dice Sistema, no un id suelto" do
    PaperTrail::Version.where(item_type: "Paquete", item_id: @paquete.id).delete_all
    PaperTrail.request(whodunnit: nil) do
      @paquete.update!(descripcion: "cambio de un job")
    end

    get paquete_url(@paquete)

    assert_match(/Sistema/, response.body)
  end
end
