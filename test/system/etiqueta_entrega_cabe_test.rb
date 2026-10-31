require "application_system_test_case"

# C30-19 · PR-P.3 · La etiqueta de entrega cabe, con el nombre y la sucursal
# más largos y la franja de consolidando puesta.
#
# Se mide en Chrome y no a ojo, como la del bulto y la de medición:
# `overflow: hidden` recorta **en silencio**, y ninguna fila de esta etiqueta
# se puede cortar.
#
# C31-17 · Ahora **horizontal** (6 × 4 in) y con otra jerarquía: grande la
# sucursal, el tipo de envío, el código, el número de PF y el QR (*"que lo lea
# bien el celular"*); chico lo demás (*"las medidas y todo eso, en pequeño
# está perfecto"*). Y una por bolsa.
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
    clientes(:juan).update_columns(nombre: "María Fernanda", apellido: "Rodríguez Castellanos")
    # C32-02 · Un nombre de verdad (`db/seeds.rb`): a 42pt «HUMUYA» / «TGU».
    sucursales(:zeron_sps).update_columns(nombre: "Humuya TGU")
    flete(paquete, 999.99)

    con_franja { visit etiqueta_entrega_pre_factura_path(@pf) }

    assert_operator caja_de(".sucursal")[:height], :>, puntos(".sucursal") * 1.5, "la sucursal no quedó en dos renglones"
    assert_operator caja_de(".nombre")[:height], :>, puntos(".nombre") * 1.5, "el nombre no quedó en dos renglones"
    assert_equal 42, (puntos(".sucursal") * 72 / 96).round, "la sucursal se achicó: no es el caso a tamaño completo"
    assert_cabe
  end

  # C34-08 · Otra sucursal: «VA PARA», en negro. La peor otra vez —dos
  # renglones a tamaño completo, nombre en dos, la franja— y tiene que caber
  # con el rótulo más grande.
  test "otra sucursal dice VA PARA enmarcado, y cabe a tamaño completo con la franja" do
    clientes(:juan).update_columns(nombre: "María Fernanda", apellido: "Rodríguez Castellanos")
    # A 42pt «HUMUYA» / «TGU», como el caso de San Pedro: el negro no achica.
    flete(paquete(sucursal: sucursales(:humuya_tgu)), 999.99)

    con_franja { visit etiqueta_entrega_pre_factura_path(@pf) }

    assert_selector ".izq.otra .rotulo", text: "VA PARA"
    # C34 · Enmarcado, no relleno: *"una torta negra, mucha tinta"*.
    estilo = page.evaluate_script("(function(){var s=getComputedStyle(document.querySelector('.izq.otra .destino'));" \
                                  "return [s.borderTopStyle, s.borderTopWidth, s.backgroundColor];})()")
    assert_equal "solid", estilo[0]
    assert_operator estilo[1].to_f, :>=, 2, "el marco tiene que gritar"
    assert_includes [ "rgba(0, 0, 0, 0)", "rgb(255, 255, 255)" ], estilo[2], "sin relleno negro"
    assert_operator caja_de(".sucursal")[:height], :>, puntos(".sucursal") * 1.5, "la sucursal no quedó en dos renglones"
    assert_equal 42, (puntos(".sucursal") * 72 / 96).round, "la sucursal se achicó"
    assert_cabe
  end

  # C34 · El número de la pre-alerta, como en la etiqueta del volumen.
  test "lleva el número de la pre-alerta de lo que va adentro, y cabe" do
    p = paquete
    pa = PreAlerta.create!(numero_documento: "PA-000120", cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                           consolidado: true, estado: "pre_alerta", titulo: "Consolidado",
                           creado_por_tipo: "usuario", creado_por_id: users(:admin).id)
    pa.pre_alerta_paquetes.create!(tracking: p.tracking, descripcion: "Bulto", fecha: Date.current, paquete: p)
    bulto, = MedirBulto.new(user: users(:admin)).guardar!(paquete_ids: [ p.id ], volumenes: [ { peso: "5" } ])
    @pf.pre_factura_items.create!(concepto: "Flete", paquete: p, bulto: bulto, peso_cobrar: 5, precio_libra: 1, origen: "volumen")
    @pf.update_columns(etiquetas: 3)

    con_franja { visit etiqueta_entrega_pre_factura_path(@pf) }

    assert_selector ".pa", text: "PA-000120", minimum: 1
    assert_cabe
  end

  test "San Pedro sigue diciendo RETIRA EN, sin el negro" do
    flete(paquete, 1)

    visit etiqueta_entrega_pre_factura_path(@pf)

    assert_selector ".rotulo", text: "RETIRA EN"
    assert_no_selector ".izq.otra"
  end

  test "va acostada: 6 de ancho por 4 de alto" do
    flete(paquete, 1)

    visit etiqueta_entrega_pre_factura_path(@pf)

    etiqueta = caja_de(".entrega")
    assert_in_delta 6 * 96, etiqueta[:width], 1
    assert_in_delta 4 * 96, etiqueta[:height], 1
    assert_includes page.html, "size: 6in 4in"
  end

  # *"Así en medio, que estorbe"* — pero *"aquí no puede ser el mismo lugar
  # del QR"*: acostada, la franja va de borde a borde debajo del QR y de los
  # datos de arriba, y encima del número de PF. No toca nada que se escanee.
  test "la franja va entre arriba y abajo, a todo el ancho, y no tapa el QR" do
    la_peor

    con_franja { visit etiqueta_entrega_pre_factura_path(@pf) }

    franja = caja_de(".franja")
    qr = caja_de(".qr svg")
    etiqueta = caja_de(".entrega")

    assert_operator franja[:top], :>=, qr[:bottom], "la franja se mete en el QR"
    assert_operator franja[:top], :>=, caja_de(".izq")[:bottom], "la franja tapa los datos de arriba"
    assert_operator franja[:bottom], :<=, caja_de(".abajo")[:top], "la franja tapa el número de PF"
    # C34 · Enmarcada y no rellena: va a todo el ancho de adentro, sin tocar
    # el borde del papel (el marco se cortaría).
    assert_in_delta etiqueta[:width] - 2 * 0.16 * 96, franja[:width], 1, "la franja va a todo el ancho"
    assert_equal "rgba(0, 0, 0, 0)", page.evaluate_script("getComputedStyle(document.querySelector('.franja')).backgroundColor"),
                 "sin relleno negro: *una torta negra, mucha tinta*"
    assert_operator franja[:top], :>, etiqueta[:top] + etiqueta[:height] * 0.3, "la franja quedó arriba, no en el medio"
  end

  # C31-17 · Grande: sucursal, tipo, código y PF. Chico: las cifras y la
  # fecha. Y el QR de 2.2in, que es lo que lee un celular sin pelear.
  test "lo grande es la sucursal, el tipo, el código y el PF; lo chico, las cifras y la fecha; el QR, 2.2in" do
    flete(paquete, 12.5)

    visit etiqueta_entrega_pre_factura_path(@pf)

    assert_cabe
    grandes = %w[.sucursal .tipo .cliente-codigo .pf].map { |s| puntos(s) }
    chicos = [ ".cifra .v", ".fecha" ].map { |s| puntos(s) }
    assert_operator grandes.min, :>, chicos.max * 2, "#{grandes} contra #{chicos}"
    assert_operator grandes.min, :>, puntos(".nombre"), "el nombre quedó más grande que lo que Yusef pidió grande"
    assert_operator caja_de(".qr svg")[:width], :>=, 2.2 * 96 - 1, "el QR quedó chico para el celular"
  end

  # C31-17 · *"Cuántas etiquetas el F9"*: una por bolsa, cada una entera.
  # Es la más apretada: «1 de 3» le quita lugar a las cifras, que envuelven, y
  # con la franja puesta.
  test "con tres etiquetas salen tres, cada una «i de 3» y entera, con la franja puesta" do
    la_peor
    @pf.update_columns(etiquetas: 3)

    con_franja { visit etiqueta_entrega_pre_factura_path(@pf) }

    assert_selector ".entrega", count: 3
    assert_equal [ "1 de 3", "2 de 3", "3 de 3" ], all(".bolsa").map(&:text)
    assert_equal 26, (puntos(".pf") * 72 / 96).round, "el número de PF se achicó para hacerle lugar a lo chico"
    3.times do |i|
      e = page.evaluate_script("(function(){var e=document.querySelectorAll('.entrega')[#{i}];" \
                               "return [e.scrollHeight, e.clientHeight, e.scrollWidth, e.clientWidth];})()")
      assert_operator e[0], :<=, e[1], "la #{i + 1} se recorta por abajo"
      assert_operator e[2], :<=, e[3], "la #{i + 1} se recorta de ancho"
    end
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
