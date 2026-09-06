require "application_system_test_case"

# C26-02 · La estación de Medición, con pistola y teclado en Chrome de verdad.
#
# Lo que importa acá no se ve en el JSON: que el foco vaya del escaneo al peso,
# que Enter avance y nunca guarde, que F10 guarde y devuelva el foco a la
# pistola, y que el problema salga en un modal rojo que Escape no cierra.
class MedicionFlujoTest < ApplicationSystemTestCase
  setup do
    users(:medidor).update!(iniciales: "MD")
    ingresar(users(:medidor))
    @paquete = Paquete.create!(tracking: "1ZFLUJO00000001", cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                               sucursal_recepcion: sucursales(:miami), estado: "en_aduana", descripcion: "Zapatos", peso: 2)
  end

  def escanear(codigo)
    find("#codigo_medicion").send_keys(codigo, :enter)
  end

  def foco = page.evaluate_script("document.activeElement.id")

  test "escanear, teclear con Enter, guardar con F10, y la pistola queda lista" do
    visit medicion_index_path
    escanear(@paquete.tracking)

    assert_selector "[data-medicion-target='panel']", text: "Juan", wait: 5
    assert_equal "medicion_peso", foco, "después de escanear, el cursor va al peso"

    send_keys "12.5", :enter
    assert_equal "medicion_alto", foco, "Enter avanza, no guarda"
    send_keys "10", :enter, "12", :enter, "14"
    assert_nil @paquete.reload.medido_at, "nada se guardó todavía"

    # C26-04 · F10 guarda **e imprime**: abre la etiqueta en pestaña nueva.
    # `window.open` se reemplaza para no abrir nada de verdad y poder afirmar
    # a dónde iba (el Chrome de los tests no bloquea popups).
    page.execute_script("window.open = function(u){ window.__abrio = u }")
    send_keys :f10
    assert_selector "[data-medicion-target='medidos'] tr", text: "Juan", wait: 5
    assert_match(%r{/medicion/#{@paquete.id}/etiqueta\?print=true}, page.evaluate_script("window.__abrio").to_s,
                 "la etiqueta se imprime al guardar")
    assert_not_nil @paquete.reload.medido_at
    assert_equal 12.5, @paquete.peso.to_f
    assert_equal "codigo_medicion", foco, "la pistola queda lista para la siguiente"
  end

  test "lo que no se encuentra es un modal rojo grande: Enter lo cierra, Escape no" do
    visit medicion_index_path
    escanear("NOEXISTE123")

    assert_selector "dialog[open]", text: "No se encontró", wait: 5
    page.driver.browser.action.send_keys(:escape).perform
    assert_selector "dialog[open]", text: "No se encontró"

    page.driver.browser.action.send_keys(:enter).perform
    assert_no_selector "dialog[open]", wait: 5
    assert_equal "codigo_medicion", foco
  end

  test "una caja de un grupo consolidado muestra cuántos faltan, y facturar lo que hay abre el modal rojo con la lista" do
    pa = PreAlerta.create!(numero_documento: "PA-T#{SecureRandom.hex(3).upcase}", cliente: clientes(:juan),
                           tipo_envio: tipo_envios(:aereo), consolidado: true, con_reempaque: true,
                           estado: "pre_alerta", titulo: "Consolidado de prueba",
                           creado_por_tipo: "usuario", creado_por_id: users(:admin).id)
    pa.pre_alerta_paquetes.create!(tracking: @paquete.tracking, descripcion: "Zapatos", fecha: Date.current, paquete: @paquete)
    pa.pre_alerta_paquetes.create!(tracking: "1ZFALTA000000009", descripcion: "Gorra", fecha: Date.current)

    visit medicion_index_path
    escanear(@paquete.tracking)

    assert_selector "[data-medicion-target='unir']", text: "llegados 1 de 2", wait: 5
    assert_selector "[data-medicion-target='unirFaltantes']", text: "1ZFALTA000000009"

    click_on "Facturar lo que hay"

    assert_selector "dialog[open]", text: "Facturar lo que hay", wait: 5
    assert_selector "dialog[open]", text: "1ZFALTA000000009"
    page.driver.browser.action.send_keys(:escape).perform
    assert_selector "dialog[open]", text: "Facturar lo que hay", wait: 2
  end
end
