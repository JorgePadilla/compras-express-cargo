require "application_system_test_case"

# C30-19 · PR-P.3 · La etiqueta de entrega cabe en la 4×6, con el nombre y la
# sucursal más largos y la franja de consolidando puesta.
#
# Se mide en Chrome y no a ojo, como la del bulto y la de medición:
# `overflow: hidden` recorta **en silencio**, y ninguna fila de esta etiqueta
# se puede cortar — el nombre y la sucursal son justo lo que Yusef pidió más
# grande (*"lo que ocupo más grande son la sucursal y el nombre del
# cliente… y el tipo de envío"*).
class EtiquetaEntregaCabeTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:supervisor_prefactura))
    @pf = PreFactura.create!(cliente: clientes(:juan), creado_por: users(:cajero), fecha_trabajo: Date.current)
  end

  def paquete(**extra)
    Paquete.create!({ tracking: "1ZENTCABE#{SecureRandom.hex(4).upcase}", cliente: clientes(:juan),
                      tipo_envio: tipo_envios(:cer), sucursal_recepcion: sucursales(:miami),
                      sucursal: sucursales(:zeron_sps), estado: "en_aduana", descripcion: "Ropa", peso: 5 }.merge(extra))
  end

  def flete(paquete, peso)
    @pf.pre_factura_items.create!(concepto: "Flete", paquete: paquete, peso_cobrar: peso, precio_libra: 1)
  end

  # PR-P.6 · La franja la prende la columna, como en la vida real (F8).
  def con_franja
    @pf.update_columns(consolidando_at: Time.current)
    yield
  ensure
    @pf.update_columns(consolidando_at: nil)
  end

  # La peor: nombre de seis palabras, la sucursal más larga, dos tipos de
  # envío, cifras de cuatro y cinco dígitos, diez volúmenes — y la franja.
  def la_peor
    clientes(:juan).update_columns(nombre: "María Fernanda de los Ángeles",
                                   apellido: "Rodríguez Castellanos Villanueva",
                                   codigo: "CEC-0012345")
    sucursales(:zeron_sps).update_columns(nombre: "Centro de Distribución Santa Rosa de Copán")
    9.times { flete(paquete(peso_volumetrico: 9999.99), 999.99) }
    flete(paquete(tipo_envio: tipo_envios(:cem), peso_volumetrico: 9999.99), 999.99)
  end

  test "la peor etiqueta cabe entera, con la franja puesta" do
    la_peor

    con_franja { visit etiqueta_entrega_pre_factura_path(@pf) }

    assert_selector ".franja", text: "CONSOLIDANDO"
    assert_cabe
    assert_text "Rodríguez Castellanos Villanueva"
    assert_text "Santa Rosa de Copán".upcase
    assert_text "9999.90"     # LBS a cobrar: diez de 999.99
    assert_text "99999.90"    # VLBS
  end

  # La otra peor: la que **no** se achica. Sucursal y nombre que caben en dos
  # renglones a tamaño completo ocupan el alto máximo — el ajuste no los toca,
  # así que lo único que la salva es el presupuesto del layout.
  test "sucursal y nombre en dos renglones a tamaño completo, con la franja, caben" do
    clientes(:juan).update_columns(nombre: "Juan Carlos", apellido: "Perez Lopez")
    sucursales(:zeron_sps).update_columns(nombre: "Zerón San Pedro")
    flete(paquete, 999.99)

    con_franja { visit etiqueta_entrega_pre_factura_path(@pf) }

    assert_operator caja_de(".sucursal")[:height], :>, puntos(".sucursal") * 1.5, "la sucursal no quedó en dos renglones"
    assert_operator caja_de(".nombre")[:height], :>, puntos(".nombre") * 1.5, "el nombre no quedó en dos renglones"
    assert_cabe
  end

  # *"Así en medio, que estorbe"* — pero *"aquí no puede ser el mismo lugar
  # del QR"*: la franja va entre los datos y el QR, y no lo toca.
  test "la franja va en el medio y no tapa el QR" do
    la_peor

    con_franja { visit etiqueta_entrega_pre_factura_path(@pf) }

    franja = caja_de(".franja")
    qr = caja_de(".qr svg")
    tipo = caja_de(".tipo")
    etiqueta = caja_de(".entrega")

    assert_operator franja[:bottom], :<=, qr[:top], "la franja se mete en el QR"
    assert_operator franja[:top], :>=, tipo[:bottom], "la franja tapa el tipo de envío"
    assert_in_delta etiqueta[:width], franja[:width], 1, "la franja va de borde a borde"
    medio = (franja[:top] + franja[:bottom]) / 2
    assert_operator medio, :>, etiqueta[:top] + etiqueta[:height] * 0.3, "la franja quedó arriba, no en el medio"
    assert_operator medio, :<, etiqueta[:top] + etiqueta[:height] * 0.7, "la franja quedó abajo, no en el medio"
  end

  test "lo más grande es la sucursal, el nombre y el tipo de envío" do
    flete(paquete, 12.5)

    visit etiqueta_entrega_pre_factura_path(@pf)

    assert_cabe
    grandes = %w[.sucursal .nombre .tipo].map { |s| puntos(s) }
    chicos = %w[.cliente-codigo .pf .fecha].map { |s| puntos(s) }
    assert_operator grandes.min, :>, chicos.max, "#{grandes} contra #{chicos}"
  end

  # Mismo ciclo que las otras etiquetas: `?print=true` abre el diálogo al
  # cargar. `window.print` se reemplaza **antes** de que cargue la página —es
  # en `onload` donde se llama—; reemplazarlo después llegaría tarde.
  test "con print=true abre el diálogo de impresión solo" do
    flete(paquete, 1)
    page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument",
                                    source: "window.__imprimio = 0; window.print = function () { window.__imprimio++ }")

    visit etiqueta_entrega_pre_factura_path(@pf, print: true)

    assert_selector ".entrega"
    assert_equal 1, page.evaluate_script("window.__imprimio"), "no se abrió el diálogo de impresión"
  end

  private

  # La etiqueta no se desborda, y ninguna fila que `data-ajustar` encoge se
  # corta: ni de ancho, ni de alto en las que envuelven (sucursal y nombre).
  def assert_cabe
    e = medir(".entrega")
    assert_operator e[:alto], :<=, e[:altoVisible], "se recortan #{e[:alto] - e[:altoVisible]}px por abajo"
    assert_operator e[:ancho], :<=, e[:anchoVisible], "se recortan #{e[:ancho] - e[:anchoVisible]}px de ancho"

    filas = page.evaluate_script("document.querySelectorAll('[data-ajustar]').length")
    assert_operator filas, :>=, 6, "faltan filas que se ajustan"
    filas.times do |i|
      f = page.evaluate_script(
        "(function(){var e=document.querySelectorAll('[data-ajustar]')[#{i}];" \
        "return [e.className, e.scrollHeight, e.clientHeight, e.scrollWidth, e.clientWidth];})()"
      )
      assert_operator f[3], :<=, f[4], "«.#{f[0]}» se corta de ancho: sobran #{f[3] - f[4]}px"
      assert_operator f[1], :<=, f[2], "«.#{f[0]}» se corta de alto: sobran #{f[1] - f[2]}px"
    end
  end

  def medir(selector)
    m = page.evaluate_script(
      "(function(){var e=document.querySelector('#{selector}');" \
      "return [e.scrollHeight, e.clientHeight, e.scrollWidth, e.clientWidth];})()"
    )
    { alto: m[0], altoVisible: m[1], ancho: m[2], anchoVisible: m[3] }
  end

  def caja_de(selector)
    r = page.evaluate_script("(function(){var r=document.querySelector('#{selector}').getBoundingClientRect();" \
                             "return [r.top, r.bottom, r.width, r.height];})()")
    { top: r[0], bottom: r[1], width: r[2], height: r[3] }
  end

  def puntos(selector)
    page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('#{selector}')).fontSize)")
  end
end
