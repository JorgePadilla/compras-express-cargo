require "application_system_test_case"

# Yusef: *"falta la observación que te hice: si después de imprimir la etiqueta,
# te tire automáticamente el Recibo de Bodega"*.
#
# El código sí lo hacía desde `PR-C7.16`: `entrega_personal_controller.js` abría
# la etiqueta y **después** el Warehouse Receipt. A Jorge se le abrían las dos
# ventanas; a Yusef no. Jorge pidió no dar por sentado el bloqueador de popups
# —primero reproducirlo—, y esto es la reproducción y la red.
#
# **Reproducido**: con el bloqueador puesto salía la etiqueta y nada más. Un
# gesto del usuario le alcanza a Chrome para **un** popup, no para dos; el
# segundo `window.open` se cae en silencio. A Jorge le funcionaba porque su
# Chrome ya tenía el permiso dado para el sitio.
#
# ⚠️ El Chrome de los tests **no bloquea popups**: chromedriver lo arranca con
# `--disable-popup-blocking`. Se comprobó — un `window.open` sin ningún gesto
# del usuario abría igual, y dos seguidas abrían dos. O sea que el harness de
# siempre no puede ver este síntoma: da verde pase lo que pase. Por eso esta
# clase corre con `:chrome_con_bloqueador_de_popups`, que es un Chrome como el
# de Miami.
class WrDespuesDeLaEtiquetaTest < ApplicationSystemTestCase
  # El driver con el bloqueador puesto vive en `application_system_test_case.rb`.
  # Tiene nombre propio a propósito: un bloque en `driven_by :selenium` se pierde
  # en la corrida completa, porque Capybara reusa el navegador de la primera
  # clase — y ahí este archivo volvía a probar contra un Chrome permisivo.
  driven_by :chrome_con_bloqueador_de_popups

  setup do
    visit new_session_path
    fill_in "email_address", with: users(:digitador).email_address
    fill_in "password", with: "password123"
    click_on "Iniciar Sesion"
    assert_no_current_path new_session_path, wait: 8
  end

  test "guardar con impresion abre una sola ventana" do
    # La de la etiqueta. Dos eran una de más y **la de más era la que se
    # perdía**: la del Warehouse Receipt.
    guardar_con_impresion

    nuevas = page.windows.drop(1)
    urls = nuevas.map { |w| page.within_window(w) { page.current_url } }

    assert_equal 1, nuevas.size, "volvió a abrir más de un popup: #{urls.join(', ')}"
    assert_match(/etiqueta\?hermanas=1&print=true&wr=1/, urls.first)
  ensure
    cerrar_pestanas_extra
  end

  test "al terminar de imprimir esa misma ventana se va al Warehouse Receipt" do
    # Headless nunca dispara `afterprint` —no hay diálogo de impresión que
    # cerrar—, así que se dispara a mano. Mismo procedimiento que usa
    # `etiqueta_cierra_ventana_test`.
    guardar_con_impresion

    en_la_ventana_de_la_etiqueta do
      assert_selector ".etq", wait: 5
      page.execute_script("window.dispatchEvent(new Event('afterprint'))")
      assert_current_path(/warehouse_receipt/, wait: 5, url: true)
      # Que la URL cambie no dice que el recibo haya salido: si el WR reventara,
      # la dirección sería la misma.
      assert_text "WAREHOUSE RECEIPT", wait: 5
    end
  ensure
    cerrar_pestanas_extra
  end

  test "una etiqueta sin wr=1 no se va al Warehouse Receipt" do
    # El resto de las pantallas imprime etiquetas y punto: en un lote de 100
    # paquetes, 100 pestañas con un Warehouse Receipt cada una sería peor que
    # el problema original. Ésas siguen cerrándose — lo cubre
    # `etiqueta_cierra_ventana_test`; acá lo que se fija es que **no naveguen**.
    #
    # Se entra pegando la URL a propósito: el navegador se niega a cerrar una
    # pestaña que no abrió por script, así que queda a la vista si navegó.
    visit "#{etiqueta_paquete_path(paquetes(:disponible_entrega_juan))}?print=true"
    assert_selector ".etq", wait: 5

    page.execute_script("window.dispatchEvent(new Event('afterprint'))")
    sleep 1

    assert_no_current_path(/warehouse_receipt/, url: true)
    assert_selector ".etq"
  end

  test "y el aviso sigue trayendo el link, por si los popups estan bloqueados del todo" do
    # `aviso_con_wr` existe justo para eso. Si Yusef tiene los popups apagados
    # para el sitio no se abre nada, y el link del flash es la única forma de
    # llegar al Warehouse Receipt.
    guardar_con_impresion

    assert_link "Ver Warehouse Receipt"
  ensure
    cerrar_pestanas_extra
  end



  private

  def guardar_con_impresion
    visit new_entrega_personal_path
    assert_selector "form", wait: 5

    find("[data-entrega-personal-target='clienteInput']").fill_in with: "Juan"
    find("[data-entrega-personal-target='clienteDropdown'] *", match: :first, wait: 5).click

    select Proveedor.where(tipo: "entrega_personal").activos.ordered.first.nombre,
           from: "paquete[proveedor_id]"
    # Sin la sucursal de Miami no hay `codigo_ep` y el tracking EP no se genera.
    select Sucursal.activas.where(ubicacion: "miami").where.not(codigo_ep: nil).first.nombre,
           from: "paquete[sucursal_recepcion_id]"
    select TipoEnvio.activos.order(:nombre).first.nombre, from: "paquete[tipo_envio_id]"
    fill_in "paquete[descripcion]", with: "Dos pares de zapatos"
    fill_in "paquete[peso]", with: "10"

    click_on "Guardar + Imprimir"
    assert_text "Entrega personal registrada", wait: 10
  end

  def en_la_ventana_de_la_etiqueta
    b = page.driver.browser
    principal = b.window_handles.first
    etiqueta = b.window_handles.last
    raise "no se abrió la ventana de la etiqueta" if etiqueta == principal

    b.switch_to.window(etiqueta)
    yield
  ensure
    b.switch_to.window(principal) if b.window_handles.include?(principal)
  end

  def cerrar_pestanas_extra
    b = page.driver.browser
    principal = b.window_handles.first
    b.window_handles[1..].to_a.each do |h|
      b.switch_to.window(h)
      b.close
    end
    b.switch_to.window(principal)
  end
end
