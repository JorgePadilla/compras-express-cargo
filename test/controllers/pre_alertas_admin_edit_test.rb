require "test_helper"

# PR-C6.25: la pantalla de editar una pre-alerta (la de admin, no la del
# portal cliente).
#
# Tres cosas, dos que reportó Yusef el 2026-08-08 y una que salió sola:
#
#   1. **El botón "Guardar (F8)" no hacía nada.** La vista no seteaba
#      `autosave-url-value` y el Stimulus corta en seco sin él
#      (`if (this._saving || !this.autosaveUrlValue) return false`). Borrar una
#      fila tampoco persistía, porque también termina en `autosave()`. Nadie lo
#      reportó: la página no da error, simplemente no guarda.
#
#   2. **La columna "Vinculado" repetía el tracking.** Yusef: "este vinculado
#      es el que no… no, porque **este es el mismo que este**". Tenía razón —
#      usaba `paquete_display_id`, que cae al tracking cuando no hay número de
#      recepción, y el paquete esperado de una pre-alerta nunca lo tiene
#      todavía.
#
#   3. **Faltaba el estado por tracking.** Yusef: "¿te acordás que aquí debería
#      ir el estatus? Si ya fue recibido, si está en estado prealerta". En
#      `show` sí estaba; en `edit` no.
class PreAlertasAdminEditTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
    @pa = pre_alertas(:activa)
  end

  test "el editor sabe a donde guardar" do
    get edit_pre_alerta_url(@pa)

    assert_match(/data-pre-alerta-editor-autosave-url-value="[^"]+"/, response.body,
                 "sin este valor el Stimulus corta y el boton Guardar no hace nada")
  end

  test "guardar por json responde ok y persiste" do
    patch pre_alerta_url(@pa, format: :json), params: {
      pre_alerta: { titulo: "Titulo corregido" }
    }

    assert_response :success
    assert_equal "Titulo corregido", @pa.reload.titulo
  end

  test "un error por json vuelve con el detalle" do
    # El caso real: dos veces el mismo tracking en la misma pre-alerta.
    pap = @pa.pre_alerta_paquetes.first
    patch pre_alerta_url(@pa, format: :json), params: {
      pre_alerta: { pre_alerta_paquetes_attributes: [
        { tracking: pap.tracking, descripcion: "Repetido" }
      ] }
    }

    assert_response :unprocessable_entity
    assert JSON.parse(response.body)["errores"].any?
  end

  test "la pantalla tiene donde mostrar el error" do
    # Antes el 422 re-renderizaba la misma pagina sin decir por que.
    pap = @pa.pre_alerta_paquetes.first
    patch pre_alerta_url(@pa), params: {
      pre_alerta: { pre_alerta_paquetes_attributes: [
        { tracking: pap.tracking, descripcion: "Repetido" }
      ] }
    }

    assert_response :unprocessable_entity
    assert_match(/data-bloque="errores"/, response.body)
  end

  test "la columna Vinculado no repite el tracking" do
    # Se crea acá y no se toma de la fixture porque el paquete "esperado" lo
    # crea un `after_create` — las fixtures no disparan callbacks.
    pap = @pa.pre_alerta_paquetes.create!(tracking: "1Z999VINC0001", descripcion: "Cosas")
    assert pap.reload.paquete.numero_recepcion.blank?

    get edit_pre_alerta_url(@pa)
    celda = celda_de(response.body, "vinculado")

    assert_no_match(/#{Regexp.escape(pap.tracking)}/, celda,
                    "la columna Vinculado vuelve a mostrar el tracking")
    assert_match(/sin recibir/, celda)
  end

  test "la columna Vinculado muestra el numero cuando ya se recibio" do
    pap = @pa.pre_alerta_paquetes.create!(tracking: "1Z999VINC0002", descripcion: "Cosas")
    pap.reload.paquete.update_columns(numero_recepcion: "RMI0002026000777")

    get edit_pre_alerta_url(@pa)

    assert_match(/RMI0002026000777/, celda_de(response.body, "vinculado"))
  end

  test "cada tracking muestra su estado" do
    get edit_pre_alerta_url(@pa)

    assert_match(/data-columna="estado"/, response.body)
  end

  private

  # Todas las celdas de esa columna, no la primera: la pre-alerta tiene varias
  # filas y la que interesa es la que crea cada test.
  def celda_de(cuerpo, columna)
    cuerpo.scan(/data-columna="#{columna}".*?<\/td>/m).join("\n")
  end
end
