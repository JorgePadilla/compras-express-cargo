require "test_helper"

# PR-C6.45: el editor de admin guarda solo, como el del portal.
#
# `pre_alerta_editor_controller` arma el debounce del autoguardado solo si
# **las dos** cosas están:
#
#   if (this.consolidadoValue && this.autosaveUrlValue) { … }
#
# `PR-C6.25` puso la URL. `consolidado-value` nunca estuvo, así que la compuerta
# era `undefined && url` → false: el debounce **jamás se armó** y F8 quedó como
# la única forma de guardar. Y hasta `PR-C6.43`, apretar F8 dos veces duplicaba
# el paquete — que es exactamente lo que pasa cuando guardar cuesta trabajo.
#
# El límite de paquetes es el otro faltante: `respect_max_paquetes_por_accion`
# lo valida en el servidor, pero admin podía llenar tres filas de un CKA y
# enterarse recién al guardar. El portal avisa desde el principio.
class PreAlertasAdminAutoguardadoTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
    @pa = pre_alertas(:activa)
  end

  test "el editor sabe que tiene que guardar solo" do
    @pa.update_columns(consolidado: true, finalizado: false)

    get edit_pre_alerta_url(@pa)

    assert_match(/data-pre-alerta-editor-consolidado-value="true"/, response.body,
      "sin este valor la compuerta del debounce es false y F8 es lo unico que guarda")
  end

  test "una consolidacion finalizada NO se sigue guardando sola" do
    # `consolidando?` y no `consolidado?`: los dos son true mientras se trabaja,
    # pero al finalizar solo el primero se apaga. Con el segundo, una pre-alerta
    # cerrada seguiría auto-guardándose a cada tecla.
    @pa.update_columns(consolidado: true, finalizado: true)

    get edit_pre_alerta_url(@pa)

    assert_match(/data-pre-alerta-editor-consolidado-value="false"/, response.body)
  end

  test "sin consolidar tampoco guarda solo" do
    # Igual que el portal: el autoguardado es para la sesión larga de armar una
    # consolidación, no para una pre-alerta suelta.
    @pa.update_columns(consolidado: false, finalizado: false)

    get edit_pre_alerta_url(@pa)

    assert_match(/data-pre-alerta-editor-consolidado-value="false"/, response.body)
  end

  # ── El límite de paquetes ──

  test "un servicio de un solo paquete avisa el limite" do
    @pa.update_columns(tipo_envio_id: tipo_envios(:cka).id)

    get edit_pre_alerta_url(@pa)

    assert_match(/data-pre-alerta-editor-max-paquetes-value="1"/, response.body)
    assert_select "[data-pre-alerta-editor-target=limitMessage]"
    assert_match(/solo permite 1 paquete/, response.body)
  end

  test "un servicio sin limite no inventa uno" do
    @pa.update_columns(tipo_envio_id: tipo_envios(:cer).id)

    get edit_pre_alerta_url(@pa)

    assert_match(/data-pre-alerta-editor-max-paquetes-value="-1"/, response.body)
    assert_select "[data-pre-alerta-editor-target=limitMessage]", count: 0
  end

  test "el limite que se muestra es el que valida el modelo" do
    # Si divergen, la pantalla miente: deja agregar y el guardado rechaza.
    @pa.update_columns(tipo_envio_id: tipo_envios(:cka).id)

    get edit_pre_alerta_url(@pa)

    assert_equal tipo_envios(:cka).max_paquetes_por_accion,
                 response.body[/max-paquetes-value="(-?\d+)"/, 1].to_i
  end

  # ── Que el guardado se vea ──

  test "el editor tiene donde decir que esta guardando" do
    # Sin esto el autoguardado es invisible: el operario escribe, no toca nada
    # mas, y no sabe si quedo.
    get edit_pre_alerta_url(@pa)

    assert_select "[data-pre-alerta-editor-target=status]"
    assert_select "[data-pre-alerta-editor-target=savedModal]"
  end

  test "los atajos no se registran dos veces" do
    # `pre_alerta_editor_controller` ya escucha las teclas en `document`. Si
    # algun boton llevara `data-shortcut`, el handler global le haria click
    # ademas, y la accion correria dos veces.
    #
    # C23-13 · Las teclas cambiaron —eran F6 agregar y F8 guardar, y en el resto
    # de la app F6 es editar y F8 es Excel— pero **la propiedad que este test
    # cuida es la misma**: el rotulo se ve y `data-shortcut` no se emite. Ahora
    # el rotulo lo pinta `shortcut_label_only` en vez de ir escrito a mano
    # adentro del texto, que es como se le escondian al lint de teclas.
    get edit_pre_alerta_url(@pa)

    assert_select "[data-shortcut]", count: 0
    # El rotulo lo pinta el componente en su propio `<span>`, asi que se afirma
    # por el texto del boton y no contra el HTML crudo.
    assert_select "a,button", text: /Guardar\s*\(F10\)/, count: 1
    assert_select "a,button", text: /Agregar Paquete\s*\(F5\)/, count: 1
  end
end
