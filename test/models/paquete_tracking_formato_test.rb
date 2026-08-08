require "test_helper"

# PR-10.d (review): el tracking se imprime en la etiqueta y alimenta el código
# de barras. `PreAlertaPaquete` ya validaba su formato y `Paquete` no.
class PaqueteTrackingFormatoTest < ActiveSupport::TestCase
  def nuevo(tracking)
    Paquete.new(tracking: tracking, cliente: clientes(:juan), sucursal: sucursales(:miami))
  end

  test "acepta los formatos reales que se usan hoy" do
    [
      "1Z999AA10123456784",        # UPS
      "TBA333187639911-2-1",       # Amazon
      "EP-2026-SM-AMZ-000001",     # entrega personal
      "RC-2026-SM-AMZ-000001",     # recolecta
      "1Z999SPLIT_B1",             # split en tests
      "9400.1118.9922.3456"        # USPS con puntos
    ].each do |t|
      assert nuevo(t).valid?, "deberia aceptar #{t}: #{nuevo(t).tap(&:valid?).errors[:tracking]}"
    end
  end

  test "rechaza espacios y caracteres de markup" do
    [ "1Z999 CON ESPACIO", '1Z999"><script>', "1Z999<b>", "1Z999&amp;" ].each do |t|
      p = nuevo(t)
      assert_not p.valid?, "deberia rechazar #{t.inspect}"
      assert_includes p.errors[:tracking].join, "no permite espacios ni símbolos"
    end
  end

  # El código de barras se genera con el numero_recepcion, que es de
  # generación interna — pero si algo raro llegara, barby escapa el texto y el
  # helper degrada a solo texto en vez de tumbar la impresión.
  test "el generador de codigo de barras escapa el markup" do
    svg = ActionController::Base.helpers.extend(EtiquetaHelper)
                                .etiqueta_barcode_svg('RE001"><script>alert(1)</script>')

    assert_not_nil svg
    assert_no_match(/<script>/, svg, "barby debe escapar el texto del <title>")
    assert_match(/&lt;script&gt;/, svg)
  end

  test "el generador degrada a nil si el valor no es codificable" do
    svg = ActionController::Base.helpers.extend(EtiquetaHelper).etiqueta_barcode_svg("")

    assert_nil svg
  end
end
