require "test_helper"

# C26-02 · Lo que lee la pistola en Medición: estricto.
class PaquetePorCodigoDeEtiquetaTest < ActiveSupport::TestCase
  setup do
    @madre = "RMI0002026000900"
    @c1 = caja(1)
    @c2 = caja(2)
  end

  test "el código de la caja cae en su caja y no en sus hermanas" do
    assert_equal [ @c2 ], Paquete.por_codigo_de_etiqueta("#{@madre}-2").to_a
    assert_equal [ @c1 ], Paquete.por_codigo_de_etiqueta("rmi0002026000900-1").to_a, "sin importar mayúsculas"
  end

  # C26-02 · Este test decía «es ambiguo» y **codificaba el requisito
  # equivocado**: escanear el warehouse receipt de un envío partido tiene que
  # traer sus cajas, no rechazarlas. Jorge, al usarlo: *"escaneé el warehouse
  # receipt y me deberían aparecer los datos de los otros paquetes"*. Quien
  # decide qué hacer con las varias es la estación, no esta consulta.
  test "el número de recepción de un envío partido trae todas sus cajas" do
    assert_equal [ @c1, @c2 ], Paquete.por_codigo_de_etiqueta(@madre).order(:numero_caja).to_a
  end

  test "el tracking exacto también sirve, y una descripción no" do
    assert_equal 2, Paquete.por_codigo_de_etiqueta("1ZSPLIT000000900").count, "las dos cajas del tracking"
    assert_empty Paquete.por_codigo_de_etiqueta("Zapatos"), "no adivina por descripción como `buscar`"
    assert_empty Paquete.por_codigo_de_etiqueta("")
  end

  private

  def caja(n)
    Paquete.create!(tracking: "1ZSPLIT000000900", cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                    sucursal_recepcion: sucursales(:miami), estado: "en_aduana", descripcion: "Zapatos", peso: 2,
                    numero_recepcion: @madre, numero_caja: n, cantidad_paquetes: 2)
  end
end
