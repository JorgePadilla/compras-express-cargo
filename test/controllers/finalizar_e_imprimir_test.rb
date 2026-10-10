require "test_helper"

# C30-05 · «Finalizar e Imprimir» saca **la hoja del manifiesto**, no las 4×6.
#
# Yusef, 2026-10-09, probándolo en staging:
#
#   > "Lo que tiene que imprimirme no es esta etiqueta… el que necesito que me
#   >  imprima después de finalizado es este. Este es el que ellos imprimen
#   >  después de finalizado, porque todas esas etiquetas ya las imprimieron
#   >  cuando los estaban ingresando."
#   > "Ahora que yo le doy finalizar… me está imprimiendo ésta otra vez."
#
# Cambia `C21-06`, que lo había leído del diagrama como *"finalizar e imprimir
# todos los bultos"*.
class FinalizarEImprimirTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @manifiesto = manifiestos(:creado)
    @paquete = paquetes(:empacado)
    @paquete.update!(manifiesto: @manifiesto)
    @manifiesto.recalculate_totals!
  end

  test "finaliza y manda a la hoja del manifiesto, con el diálogo y la vuelta a la ficha" do
    @manifiesto.cajas.create!(tamano_caja: tamano_cajas(:mediana), peso: 10, user: @user)

    patch finalizar_manifiesto_url(@manifiesto, imprimir: true)

    assert_redirected_to documento_manifiesto_path(@manifiesto, print: true, volver: 1)
    assert_equal "enviado", @manifiesto.reload.estado
  end

  test "ya no manda a las 4×6 de los bultos" do
    @manifiesto.cajas.create!(tamano_caja: tamano_cajas(:mediana), peso: 10, user: @user)

    patch finalizar_manifiesto_url(@manifiesto, imprimir: true)

    assert_no_match %r{/cajas/etiquetas}, response.location
  end

  test "sin bultos también imprime: la hoja sale igual" do
    # El manifiesto que se armó sin escanear (`C23-10`) no tiene cajas. Antes
    # el botón ni aparecía y, si llegaba el parámetro, finalizaba sin imprimir.
    assert_empty @manifiesto.cajas

    patch finalizar_manifiesto_url(@manifiesto, imprimir: true)

    assert_redirected_to documento_manifiesto_path(@manifiesto, print: true, volver: 1)
  end

  test "«Solo Finalizar» sigue volviendo a la ficha sin imprimir nada" do
    patch finalizar_manifiesto_url(@manifiesto)
    assert_redirected_to manifiesto_url(@manifiesto)
  end

  # ── La hoja, cuando se lleva la pestaña ─────────────────────────────────

  test "con volver=1 la hoja sabe volver a la ficha al terminar de imprimir" do
    get documento_manifiesto_url(@manifiesto, print: true, volver: 1)

    assert_response :success
    assert_includes response.body, "var despues = #{manifiesto_path(@manifiesto).to_json};"
    assert_match(/window\.location\.replace\(despues\)/, response.body)
  end

  test "sin volver la hoja no lleva a ningún lado (la de «Imprimir manifiesto» se cierra)" do
    get documento_manifiesto_url(@manifiesto, print: true, cerrar: 1)
    assert_includes response.body, 'var despues = "";'
  end

  test "el Warehouse Receipt, que comparte el layout, no aprende a irse a ningún lado" do
    get warehouse_receipt_paquete_url(@paquete, print: true, volver: 1)
    assert_response :success
    assert_includes response.body, 'var despues = "";'
  end

  # ── El botón ────────────────────────────────────────────────────────────

  test "el botón sale aunque no haya bultos, y su confirmación habla de la hoja" do
    assert_empty @manifiesto.cajas
    get manifiesto_url(@manifiesto)

    assert_select "form[action=?] button", finalizar_manifiesto_path(@manifiesto, imprimir: true), text: /Finalizar e Imprimir/, minimum: 1
    assert_includes response.body, "sale la hoja del manifiesto para el transportista"
    assert_not_includes response.body, "salen las etiquetas 4×6"
  end

  test "re-imprimir las 4×6 sigue estando, aparte" do
    caja = @manifiesto.cajas.create!(tamano_caja: tamano_cajas(:mediana), peso: 10, user: @user)
    @paquete.update_columns(caja_manifiesto_id: caja.id)

    get manifiesto_url(@manifiesto)
    assert_includes response.body, "Imprimir las 4×6"
  end
end
