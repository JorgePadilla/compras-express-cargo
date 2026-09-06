require "application_system_test_case"

# C26-02/03 · La estación de Medición, con pistola y teclado en Chrome.
#
# Lo que importa acá no se ve en el JSON: que la grilla del grupo se pinte y
# cambie sin recargar, que el foco vaya del escaneo al peso, que Enter avance y
# nunca guarde, y que al completar el grupo se abra **una** impresión con todas
# las stickers.
class MedicionFlujoTest < ApplicationSystemTestCase
  setup do
    users(:medidor).update!(iniciales: "MD")
    ingresar(users(:medidor))
    @paquete = caja("1ZFLUJO00000001")
  end

  def caja(tracking)
    p = Paquete.create!(tracking: tracking, cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                        sucursal_recepcion: sucursales(:miami), estado: "recibido_miami", descripcion: "Zapatos", peso: 2)
    p.update!(estado: "en_aduana")
    p.reload
  end

  def escanear(codigo) = find("#codigo_medicion").send_keys(codigo, :enter)

  # Escanear y **esperar a que la caja esté en pantalla** antes de teclear: sin
  # esto las teclas se van al campo de escaneo, que todavía tiene el foco, y el
  # Enter dispara un segundo escaneo de basura.
  def escanear_y_medir(paquete, peso, alto, largo, ancho)
    escanear(paquete.numero_recepcion)
    assert_selector "[data-medicion-target='codigoCaja']", text: paquete.numero_recepcion, wait: 5
    send_keys peso, :enter, alto, :enter, largo, :enter, ancho
  end
  def foco = page.evaluate_script("document.activeElement.id")
  def espiar_impresion = page.execute_script("window.__abrio = null; window.open = function(u){ window.__abrio = u }")
  def lo_que_abrio = page.evaluate_script("window.__abrio").to_s

  test "una caja sola: escanear, teclear con Enter, guardar con F10, y sale su sticker" do
    visit medicion_index_path
    escanear(@paquete.tracking)

    assert_selector "[data-medicion-target='panel']", text: "Juan", wait: 5
    assert_selector "[data-medicion-target='panelMiami']", text: @paquete.numero_recepcion
    assert_equal "medicion_peso", foco, "después de escanear, el cursor va al peso"

    send_keys "12.5", :enter
    assert_equal "medicion_alto", foco, "Enter avanza, no guarda"
    send_keys "10", :enter, "12", :enter, "14"
    assert_nil @paquete.reload.medido_at, "nada se guardó todavía"

    espiar_impresion
    send_keys :f10

    assert_selector "[data-medicion-target='medidos'] tr", text: "Juan", wait: 5
    assert_equal 12.5, @paquete.reload.peso.to_f
    assert_equal "MD", @paquete.medido_por
    assert_match(%r{/medicion/#{@paquete.id}/etiqueta\?print=true}, lo_que_abrio)
    assert_equal "codigo_medicion", foco, "la pistola queda lista para la siguiente"
  end

  test "un grupo de tres: la grilla se pinta, cambia al medir, y las tres stickers salen juntas" do
    pa, otros = grupo_de_tres(@paquete)

    visit medicion_index_path
    escanear(@paquete.tracking)

    assert_selector "[data-medicion-target='grupoTitulo']", text: "UNIR", wait: 5
    assert_selector "[data-medicion-target='grupoTitulo']", text: "0 de 3 medidas"
    assert_selector "[data-medicion-target='grilla'] button", count: 3
    assert_selector "[data-medicion-target='panelPreAlerta']", text: pa.numero_documento
    # Los dos que el cliente declaró y Miami todavía no tiene.
    assert_selector "[data-medicion-target='grilla'] button[data-estado='esperada']", count: 2

    # La primera, medida: su cuadrito cambia sin recargar.
    send_keys "12.5", :enter, "10", :enter, "12", :enter, "14"
    send_keys :f10
    assert_selector "[data-medicion-target='grupoTitulo']", text: "1 de 3 medidas", wait: 5
    assert_selector "[data-medicion-target='grilla'] button[data-estado='medida']", count: 1

    # La segunda.
    escanear_y_medir(llego(otros.first), "8", "9", "9", "9")
    send_keys :f10
    assert_selector "[data-medicion-target='grupoTitulo']", text: "2 de 3 medidas", wait: 5

    # La tercera cierra el grupo: una sola impresión, con las tres.
    escanear_y_medir(llego(otros.last), "5", "6", "7", "8")
    espiar_impresion
    send_keys :f10

    assert_selector "[data-medicion-target='banner']", text: "3 de 3 medidas", wait: 5
    assert_equal etiquetas_grupo_medicion_path(pa, print: "true"), lo_que_abrio,
                 "las tres stickers salen en una sola impresión"
  end

  test "tocar un cuadrito que ya llegó lo selecciona, sin pistola" do
    _pa, otros = grupo_de_tres(@paquete)
    segunda = llego(otros.first)

    visit medicion_index_path
    escanear(@paquete.tracking)
    assert_selector "[data-medicion-target='grilla'] button", count: 3, wait: 5

    find("[data-medicion-target='grilla'] button[data-wr='#{segunda.numero_recepcion}']").click

    assert_selector "[data-medicion-target='codigoCaja']", text: segunda.numero_recepcion, wait: 5
    assert_equal "medicion_peso", foco
  end

  test "facturar lo que hay abre el modal rojo con lo que falta, y Escape no lo cierra" do
    grupo_de_tres(@paquete)

    visit medicion_index_path
    escanear(@paquete.tracking)
    assert_selector "[data-medicion-target='facturarParcial']", wait: 5

    click_on "Facturar lo que hay"

    assert_selector "dialog[open]", text: "Facturar lo que hay", wait: 5
    assert_selector "dialog[open]", text: "1ZFALTA000000001 · no ha llegado a Miami"
    page.driver.browser.action.send_keys(:escape).perform
    assert_selector "dialog[open]", text: "Se va a seguir sin estas cajas"

    click_on "Sí, facturar lo que hay"
    assert_no_selector "dialog[open]", wait: 5
    assert_selector "[data-medicion-target='grupoSello']", text: "MD"
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

  # C26-02 · Jorge: *"escaneé el warehouse receipt y me deberían aparecer los
  # datos de los otros paquetes… que me permita tomar las medidas y el peso, y
  # luego entonces podamos imprimir la sticker"*. Las tres cajas llevan el
  # mismo código impreso, así que la pantalla encadena sola.
  test "un envío partido: se escanea el warehouse receipt una vez y se miden las tres seguidas" do
    cajas = envio_partido(@paquete, 3)

    visit medicion_index_path
    escanear(@paquete.reload.numero_recepcion)

    assert_selector "[data-medicion-target='grupoTitulo']", text: "3 cajas", wait: 5
    assert_selector "[data-medicion-target='grilla'] button", count: 3
    assert_selector "[data-medicion-target='codigoCaja']", text: "#{@paquete.numero_recepcion}-1"
    assert_equal "medicion_peso", foco

    # La primera: al guardar, la pantalla salta sola a la segunda.
    send_keys "10", :enter, "10", :enter, "10", :enter, "10"
    send_keys :f10
    assert_selector "[data-medicion-target='codigoCaja']", text: "#{@paquete.numero_recepcion}-2", wait: 5
    assert_equal "medicion_peso", foco, "el cursor queda listo para la siguiente caja"
    assert_selector "[data-medicion-target='grilla'] button[data-estado='medida']", count: 1

    # La segunda, igual.
    send_keys "11", :enter, "11", :enter, "11", :enter, "11"
    send_keys :f10
    assert_selector "[data-medicion-target='codigoCaja']", text: "#{@paquete.numero_recepcion}-3", wait: 5

    # La tercera cierra el envío: una sola impresión con las tres stickers.
    send_keys "12", :enter, "12", :enter, "12", :enter, "12"
    espiar_impresion
    send_keys :f10

    assert_selector "[data-medicion-target='banner']", text: "3 de 3 medidas", wait: 5
    assert_equal etiqueta_medicion_path(cajas.first, hermanas: "1", print: "true"), lo_que_abrio
    assert_equal 3, Paquete.where(numero_recepcion: @paquete.numero_recepcion).where.not(medido_at: nil).count
  end

  private

  def grupo_de_tres(paquete)
    pa = PreAlerta.create!(numero_documento: "PA-T#{SecureRandom.hex(3).upcase}", cliente: clientes(:juan),
                           tipo_envio: tipo_envios(:aereo), consolidado: true, estado: "pre_alerta",
                           titulo: "Consolidado de prueba", creado_por_tipo: "usuario", creado_por_id: users(:admin).id)
    pa.pre_alerta_paquetes.create!(tracking: paquete.tracking, descripcion: "Zapatos", fecha: Date.current,
                                   paquete: paquete)
    otros = %w[1ZFALTA000000001 1ZFALTA000000002].map do |t|
      pa.pre_alerta_paquetes.create!(tracking: t, descripcion: "Gorra", fecha: Date.current).paquete
    end
    [ pa, otros ]
  end

  # Un envío partido, como lo deja `crear_split!`: mismo warehouse receipt,
  # cada caja con su número.
  def envio_partido(madre, n)
    madre.update!(cantidad_paquetes: n, numero_caja: 1)
    [ madre.reload, *(2..n).map { |i|
      Paquete.create!(tracking: madre.tracking, cliente: madre.cliente, tipo_envio: madre.tipo_envio,
                      sucursal_recepcion: sucursales(:miami), estado: madre.estado, descripcion: madre.descripcion,
                      peso: 2, numero_recepcion: madre.numero_recepcion, cantidad_paquetes: n, numero_caja: i)
    } ]
  end

  def llego(paquete)
    paquete.update!(estado: "recibido_miami", sucursal_recepcion: sucursales(:miami))
    paquete.update!(estado: "en_aduana")
    paquete.reload
  end
end
