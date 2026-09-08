require "application_system_test_case"

# C26-04 · La etiqueta de medición cabe en la Dymo, con los números más largos.
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

    medidas = page.evaluate_script("(function(){var m=document.querySelector('.med');return [m.scrollHeight, m.clientHeight, m.scrollWidth, m.clientWidth];})()")
    assert_operator medidas[0], :<=, medidas[1], "se recortan #{medidas[0] - medidas[1]}px por abajo"
    assert_operator medidas[2], :<=, medidas[3], "se recortan #{medidas[2] - medidas[3]}px de ancho"

    assert_text "999.50"
    assert_text "RMI0002026000901-12"
    # C26-18 · El «n de m» impreso, que es lo que mira la persona de
    # pre-factura antes de volver a escanear. Va en la misma línea del código
    # porque en esta etiqueta no cabe una fila más, así que la peor etiqueta
    # —caja 12 de 12, con los números más largos— es justo la que tiene que
    # seguir cabiendo, y eso lo miden las dos aserciones de arriba.
    assert_text "12/12"
    assert_selector ".qr svg"
  end
end
