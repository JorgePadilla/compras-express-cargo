require "application_system_test_case"

# C26-04 / C27-06 · La etiqueta de medición cabe en la Dymo, con los números más
# largos. La 2.25×1.25 **no tiene una fila más**, así que cada dato nuevo entra
# en una fila que ya existe y `data-ajustar` la encoge hasta que quepa.
#
# C30-01 · La excepción es el cliente, que tiene fila propia arriba y la paga el
# QR, achicado a 0.90in. Por eso el alto ahora se mide con decimales.
#
# Se mide en Chrome y no a ojo: [[project_la_dymo_no_tiene_una_fila_mas]].
class EtiquetaMedicionCabeTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:medidor))
    @paquete = Paquete.create!(tracking: "1ZMEDLABEL000001", cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                               sucursal_recepcion: sucursales(:miami), estado: "en_aduana", descripcion: "Zapatos",
                               numero_recepcion: "RMI0002026000901", numero_caja: 12, cantidad_paquetes: 12,
                               peso: 999.5, alto: 99.5, largo: 99.5, ancho: 99.5,
                               medido_at: Time.current, medido_por: "MD")
  end

  test "la etiqueta más cargada no se desborda, y el QR lleva el código con los datos" do
    visit etiqueta_medicion_path(@paquete)

    assert_cabe
    assert_text "999.50"
    assert_text "RMI0002026000901-12"
    # C26-18 · El «n de m» impreso, que es lo que mira la persona de
    # pre-factura antes de volver a escanear. Va en la misma línea del código
    # porque en esta etiqueta no cabe una fila más, así que la peor etiqueta
    # —caja 12 de 12, con los números más largos— es justo la que tiene que
    # seguir cabiendo, y eso lo miden las aserciones de `assert_cabe`.
    assert_text "12/12"
    assert_selector ".qr svg"
  end

  # C27-06 · La del bulto lleva **dos datos más** que la de la caja: cuántas
  # cajas ampara —*"ella también tiene que escanear cada warehouse"*— y el «n de
  # m» de **mediciones** —*"si no escanea la segunda medición no se le agrega;
  # esa es una manera de auditar las mediciones"*—. La peor de todas: la décima
  # de diez mediciones, con cien cajas adentro y los números más largos.
  test "la etiqueta del bulto tampoco se desborda, con diez mediciones y cien cajas" do
    bulto = Bulto.create!(cliente: clientes(:juan), sesion: SecureRandom.uuid, orden: 10, de_cuantos: 10,
                          medido_at: Time.current, medido_por: "MD",
                          peso: 999.5, alto: 99.5, largo: 99.5, ancho: 99.5)
    @paquete.update!(medicion_sesion: bulto.sesion)
    99.times { |i| caja_del(bulto, i) }

    visit etiqueta_bulto_medicion_path(bulto)

    assert_cabe
    assert_text "999.50"
    assert_text "100 cajas"
    assert_text "10 de 10"
    assert_text "RMI0002026000901-12"
    assert_selector ".qr svg"
  end

  # C29-15 · El número de la pre-alerta entra en la fila del código: *"solo el
  # número de pre-alerta. PA, tal"*. La peor: la décima de diez, y con **dos**
  # pre-alertas independientes, que la etiqueta no puede callarse —sale la
  # primera y «+1»—. Todo en una fila que ya existía, y sin recortar nada.
  test "la etiqueta del bulto con su pre-alerta, en la peor tanda, sigue cabiendo" do
    bulto = Bulto.create!(cliente: clientes(:juan), sesion: SecureRandom.uuid, orden: 10, de_cuantos: 10,
                          medido_at: Time.current, medido_por: "MD",
                          peso: 999.5, alto: 99.5, largo: 99.5, ancho: 99.5)
    @paquete.update!(medicion_sesion: bulto.sesion)
    otra = caja_del(bulto, 1)
    pre_alerta_de(@paquete, "PA-999998")
    pre_alerta_de(otra, "PA-999999")

    visit etiqueta_bulto_medicion_path(bulto)

    assert_cabe
    assert_selector ".codigo", text: "PA-999998 +1"
    assert_text "RMI0002026000901-12"
    assert_text "10 de 10"
  end

  # C30-01 · El cliente, **nombre con código**, en una fila propia arriba: *"¿Quién
  # es el cliente? … No tiene nombre … Nombre con código"*. Revierte el *"no le
  # vamos a meter nombre ni nada"* de C26-04, y es la única fila más que la Dymo
  # aceptó: la pagó el QR, que bajó a 0.90in.
  #
  # La peor: un nombre de cuatro palabras con preposiciones —52 caracteres con el
  # código, más que el 99 % de los 21 mil clientes del sistema viejo— en la
  # décima de diez mediciones y con dos pre-alertas. El nombre se encoge, no se
  # corta; y el QR no baja de lo que el comentario del layout promete.
  test "el cliente va arriba con su código, y el nombre más largo cabe sin cortarse" do
    clientes(:juan).update!(nombre: "María de los Ángeles", apellido: "Castellanos Hernández")
    bulto = Bulto.create!(cliente: clientes(:juan), sesion: SecureRandom.uuid, orden: 10, de_cuantos: 10,
                          medido_at: Time.current, medido_por: "MD",
                          peso: 999.5, alto: 99.5, largo: 99.5, ancho: 99.5)
    @paquete.update!(medicion_sesion: bulto.sesion)
    otra = caja_del(bulto, 1)
    pre_alerta_de(@paquete, "PA-999998")
    pre_alerta_de(otra, "PA-999999")

    visit etiqueta_bulto_medicion_path(bulto)

    assert_cabe
    assert_selector ".med > .cliente:first-child", text: "CEC-001 · María de los Ángeles Castellanos Hernández"
    assert_selector ".cliente .cod", text: "CEC-001"
    assert_selector ".codigo", text: "PA-999998 +1"
    assert_text "10 de 10"

    # Lo que pagó la fila: el QR en 0.90in (86.4 px), y no menos.
    qr = page.evaluate_script("document.querySelector('.qr svg').getBoundingClientRect().height")
    assert_in_delta 86.4, qr, 0.5, "el QR tenía que quedar en 0.90in"
  end

  # La gemela: la etiqueta de la caja suelta (sin bulto) lleva la misma fila.
  test "la etiqueta de la caja suelta también lleva al cliente arriba" do
    visit etiqueta_medicion_path(@paquete)

    assert_cabe
    assert_selector ".med > .cliente:first-child", text: "CEC-001 · Juan Perez"
  end

  test "sin pre-alerta, la etiqueta no inventa ninguna" do
    bulto = Bulto.create!(cliente: clientes(:juan), sesion: SecureRandom.uuid, orden: 1, de_cuantos: 1,
                          medido_at: Time.current, medido_por: "MD", peso: 20)
    @paquete.update!(medicion_sesion: bulto.sesion)

    visit etiqueta_bulto_medicion_path(bulto)

    assert_text "RMI0002026000901-12"
    assert_no_text "PA-"
  end

  # Escanear la caja lleva a la etiqueta del bulto: es una por medición, no una
  # por caja.
  test "la etiqueta de una caja con bulto es la del bulto" do
    bulto = Bulto.create!(cliente: clientes(:juan), sesion: SecureRandom.uuid, orden: 1, de_cuantos: 2,
                          medido_at: Time.current, medido_por: "MD", peso: 20, alto: 10, largo: 12, ancho: 14)
    @paquete.update!(medicion_sesion: bulto.sesion)

    visit etiqueta_medicion_path(@paquete)

    assert_cabe
    assert_text "20.00"
    assert_text "1 de 2"
    # Los números que valen son los del bulto: la caja se quedó con los de Miami.
    assert_no_text "999.50"
  end

  private

  # `.med` tiene `overflow: hidden` y `.codigo` **también**: medir solo la caja
  # de afuera deja pasar una línea recortada sin que nadie se entere, y
  # [[project_etiqueta_trackings_completos]] dice que el código nunca se corta.
  # Por eso se miden las dos, y cada fila que `data-ajustar` encoge.
  #
  # C30-01 · Con la fila del cliente arriba, la etiqueta queda a ~2 px del borde,
  # y `scrollHeight` es entero: no ve décimas
  # ([[project_la_dymo_no_tiene_una_fila_mas]]). Por eso además se mide, en
  # px con decimales, que el borde de abajo del código no pase el borde
  # interior de la etiqueta.
  def assert_cabe
    caja = medir(".med")
    assert_operator caja[:alto], :<=, caja[:altoVisible], "se recortan #{caja[:alto] - caja[:altoVisible]}px por abajo"
    assert_operator caja[:ancho], :<=, caja[:anchoVisible], "se recortan #{caja[:ancho] - caja[:anchoVisible]}px de ancho"

    aire = page.evaluate_script(
      "(function(){var m=document.querySelector('.med');var r=m.getBoundingClientRect();" \
      "var pb=parseFloat(getComputedStyle(m).paddingBottom);" \
      "return (r.bottom-pb)-m.lastElementChild.getBoundingClientRect().bottom;})()"
    )
    assert_operator aire, :>=, 0, "la última fila se pasa #{-aire.round(2)}px del borde de abajo"

    %w[.cliente .codigo .fecha .dims].each do |selector|
      fila = medir(selector)
      assert_operator fila[:ancho], :<=, fila[:anchoVisible],
                      "«#{selector}» se corta: sobran #{fila[:ancho] - fila[:anchoVisible]}px"
    end
  end

  def medir(selector)
    m = page.evaluate_script(
      "(function(){var e=document.querySelector('#{selector}');" \
      "return [e.scrollHeight, e.clientHeight, e.scrollWidth, e.clientWidth];})()"
    )
    { alto: m[0], altoVisible: m[1], ancho: m[2], anchoVisible: m[3] }
  end

  def pre_alerta_de(paquete, numero)
    pa = PreAlerta.create!(numero_documento: numero, cliente: clientes(:juan), tipo_envio: tipo_envios(:aereo),
                           estado: "pre_alerta", titulo: "Pre-alerta", creado_por_tipo: "usuario",
                           creado_por_id: users(:admin).id)
    pa.pre_alerta_paquetes.create!(tracking: paquete.tracking, descripcion: "Zapatos", fecha: Date.current, paquete: paquete)
  end

  def caja_del(bulto, i)
    Paquete.create!(tracking: "1ZMEDBULTO#{format('%06d', i)}", cliente: clientes(:juan),
                    tipo_envio: tipo_envios(:cer), sucursal_recepcion: sucursales(:miami),
                    estado: "en_aduana", descripcion: "Zapatos", medicion_sesion: bulto.sesion)
  end
end
