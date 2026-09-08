require "application_system_test_case"

# C26-04 / C27-06 · La etiqueta de medición cabe en la Dymo, con los números más
# largos. La 2.25×1.25 **no tiene una fila más**, así que cada dato nuevo entra
# en una fila que ya existe y `data-ajustar` la encoge hasta que quepa.
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
    @paquete.update!(bulto: bulto)
    99.times { |i| caja_del(bulto, i) }

    visit etiqueta_bulto_medicion_path(bulto)

    assert_cabe
    assert_text "999.50"
    assert_text "100 cajas"
    assert_text "10 de 10"
    assert_text "RMI0002026000901-12"
    assert_selector ".qr svg"
  end

  # Escanear la caja lleva a la etiqueta del bulto: es una por medición, no una
  # por caja.
  test "la etiqueta de una caja con bulto es la del bulto" do
    bulto = Bulto.create!(cliente: clientes(:juan), sesion: SecureRandom.uuid, orden: 1, de_cuantos: 2,
                          medido_at: Time.current, medido_por: "MD", peso: 20, alto: 10, largo: 12, ancho: 14)
    @paquete.update!(bulto: bulto)

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
  def assert_cabe
    caja = medir(".med")
    assert_operator caja[:alto], :<=, caja[:altoVisible], "se recortan #{caja[:alto] - caja[:altoVisible]}px por abajo"
    assert_operator caja[:ancho], :<=, caja[:anchoVisible], "se recortan #{caja[:ancho] - caja[:anchoVisible]}px de ancho"

    %w[.codigo .fecha .dims].each do |selector|
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

  def caja_del(bulto, i)
    Paquete.create!(tracking: "1ZMEDBULTO#{format('%06d', i)}", cliente: clientes(:juan),
                    tipo_envio: tipo_envios(:cer), sucursal_recepcion: sucursales(:miami),
                    estado: "en_aduana", descripcion: "Zapatos", bulto: bulto)
  end
end
