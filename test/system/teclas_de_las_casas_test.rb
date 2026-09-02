require "application_system_test_case"

# C23-12 · Las teclas del formulario de casas, apretadas de verdad.
#
# Es la única pregunta que ningún test de integración puede contestar: el HTML
# sale igual tenga o no la tecla efecto. Lo que decide es **qué hace el
# navegador con el keydown**, y eso hay que apretarlo.
#
# Las dos cosas que se prueban acá existen porque las dos estaban rotas:
#
#   1. **La tecla no disparaba con el cursor en Peso.**
#      `keyboard_shortcuts_controller` ignora toda tecla que no sea F2 cuando
#      estás escribiendo, y acá el foco vive en Peso porque elegir un tamaño
#      manda el cursor ahí. O sea que el «(F5)» del botón era decorativo justo
#      en el momento en que se lo iba a usar.
#
#   2. **Y F5 encima recargaba.** F5 es «refrescar» del navegador. El handler
#      global sale antes de `preventDefault` cuando detecta que estás
#      escribiendo, así que el operario tecleaba el peso, apretaba la tecla que
#      el botón le prometía, y la página se recargaba **borrándole el peso**.
#
# Si alguien vuelve a poner estas teclas en el controller global, este archivo
# se pone rojo — y es el único lugar donde eso se nota.
class TeclasDeLasCasasTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))

    @manifiesto = manifiestos(:creado)
    @manifiesto.update!(sucursal_origen: sucursales(:miami))
    @tamano = tamano_cajas(:mediana)
  end

  test "F5 agrega la caja con el cursor en Peso, y no recarga la pantalla" do
    visit manifiesto_path(@manifiesto)
    elegir_tamano_y_pesar("12.5")

    assert_difference -> { @manifiesto.cajas.count }, 1 do
      page.driver.browser.action.send_keys(:f5).perform
      assert_text "agregada", wait: 5
    end
  end

  # La prueba de que **no recargó**: un marcador en `window` que solo sobrevive
  # si el navegador no volvió a cargar la página. Si `preventDefault` se cae,
  # F5 refresca, el marcador se pierde y el peso tecleado se va con él.
  test "F5 no dispara el refresh del navegador" do
    visit manifiesto_path(@manifiesto)
    page.execute_script("window.__marcador = 'vivo'")
    elegir_tamano_y_pesar("9")

    page.driver.browser.action.send_keys(:f5).perform
    assert_text "agregada", wait: 5

    # Después de agregar, la pantalla vuelve al manifiesto por su cuenta: lo que
    # se afirma es que la caja entró, no que el marcador siga. Si F5 hubiera
    # refrescado en vez de enviar, no habría caja ninguna.
    assert_equal 1, @manifiesto.cajas.count
  end

  # F9 es la del sistema viejo para «Agregar/Imprimir», y ahora es de acá:
  # «Finalizar e Imprimir» se corrió a F8 para dejársela.
  test "F9 agrega e imprime, con el cursor en Peso" do
    visit manifiesto_path(@manifiesto)
    elegir_tamano_y_pesar("18")

    assert_difference -> { @manifiesto.cajas.count }, 1 do
      page.driver.browser.action.send_keys(:f9).perform
      # Se lleva esta misma pestaña a la 4×6 — sin popup, que Chrome lo
      # bloquearía por venir de un POST y no de un gesto.
      assert_selector ".bulto", wait: 5
    end

    caja = @manifiesto.cajas.order(:id).last
    assert_current_path etiqueta_manifiesto_caja_path(@manifiesto, caja, print: true, volver: 1),
                        ignore_query: false
  end

  test "los botones muestran su tecla" do
    visit manifiesto_path(@manifiesto)

    # El rótulo va en su propio `span`, así que el texto del botón sale sin
    # espacio en el medio: «Agregar caja(F5)».
    assert_button "Agregar caja(F5)"
    assert_button "Agregar e imprimir(F9)"
  end

  private

  # El flujo real: se elige el tamaño —que pre-llena medidas y **manda el cursor
  # al peso**— y se teclea el peso. El cursor queda ahí, que es el caso que
  # importa.
  def elegir_tamano_y_pesar(peso)
    find("label", text: @tamano.nombre).click
    campo = find("#caja_manifiesto_peso")
    campo.send_keys(peso)
    assert_equal "caja_manifiesto_peso", page.evaluate_script("document.activeElement.id"),
                 "el cursor tiene que quedar en Peso: es lo que hace que la tecla no dispare sola"
  end
end
