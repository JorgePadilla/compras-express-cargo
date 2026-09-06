require "test_helper"

# C26-04 · El QR de la etiqueta de medición se lee en todo el sistema.
class PaqueteQrDeMedicionTest < ActiveSupport::TestCase
  include EtiquetaHelper

  setup do
    @paquete = Paquete.create!(tracking: "1ZQRMED000000001", cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                               sucursal_recepcion: sucursales(:miami), estado: "en_aduana", descripcion: "x",
                               numero_recepcion: "RMI0002026000777", peso: 12.5, alto: 10, largo: 12, ancho: 14,
                               medido_at: Time.current, medido_por: "MD")
  end

  test "el QR lleva el código y los datos, con espacios" do
    assert_equal "MED RMI0002026000777 12.50 10x12x14", etiqueta_qr_medicion(@paquete)
  end

  test "limpiar el escaneo devuelve el código, con cualquier separador" do
    assert_equal "RMI0002026000777", Paquete.limpiar_codigo_escaneado("MED RMI0002026000777 12.50 10x12x14")
    assert_equal "RMI0002026000777-2", Paquete.limpiar_codigo_escaneado("MED|RMI0002026000777-2|12.50|10x12x14")
    assert_equal "1ZQRMED000000001", Paquete.limpiar_codigo_escaneado("1ZQRMED000000001"), "lo que no es QR de medición, tal cual"
  end

  test "el QR resuelve en la estación, en la búsqueda general y en la de la pistola" do
    qr = etiqueta_qr_medicion(@paquete)

    assert_equal [ @paquete ], Paquete.por_codigo_de_etiqueta(qr).to_a
    assert_includes Paquete.buscar(qr).to_a, @paquete
    assert_equal [ @paquete ], Paquete.buscar_escaneado("MED 1ZQRMED000000001 12.50 10x12x14").to_a, "también por tracking"
  end
end
