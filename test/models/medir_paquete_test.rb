require "test_helper"

# C26-02 · Pesar y medir en San Pedro.
class MedirPaqueteTest < ActiveSupport::TestCase
  setup do
    @user = users(:supervisor_prefactura)
    @user.update!(iniciales: "SP")
    @paquete = Paquete.create!(tracking: "1ZMED#{SecureRandom.hex(4).upcase}", cliente: clientes(:juan),
                               tipo_envio: tipo_envios(:cer), sucursal_recepcion: sucursales(:miami),
                               estado: "en_aduana", descripcion: "Zapatos", peso: 3)
  end

  test "escribe los cuatro números y sella quién y cuándo" do
    MedirPaquete.new(@paquete, user: @user).medir!(peso: "12.5", alto: "10", largo: "12", ancho: "14")

    @paquete.reload
    assert_equal 12.5, @paquete.peso.to_f
    assert_equal [ 10.0, 12.0, 14.0 ], [ @paquete.alto, @paquete.largo, @paquete.ancho ].map(&:to_f)
    assert_equal "SP", @paquete.medido_por
    assert_not_nil @paquete.medido_at
  end

  # 10×12×14 = 1680 in³ ÷ 166 = 10.12 → .10/.60 → 10.5. El paquete lo recalcula
  # solo en `before_save`; este servicio no toca la aritmética.
  test "el volumétrico y el peso a cobrar se recalculan solos" do
    MedirPaquete.new(@paquete, user: @user).medir!(peso: "12.5", alto: "10", largo: "12", ancho: "14")

    assert_equal 10.5, @paquete.reload.peso_volumetrico.to_f
    assert_equal 12.5, @paquete.peso_cobrar.to_f, "cobra el mayor"
  end

  # *"Ya es la tercera vez que los pesamos"*: se puede, y el sello dice quién
  # puso el dato que está.
  test "medir de nuevo re-sella con el que midió" do
    MedirPaquete.new(@paquete, user: @user).medir!(peso: "12.5", alto: "10", largo: "12", ancho: "14")
    otro = users(:admin)
    otro.update!(iniciales: "AD")

    MedirPaquete.new(@paquete, user: otro).medir!(peso: "13", alto: "10", largo: "12", ancho: "14")

    assert_equal "AD", @paquete.reload.medido_por
    assert_equal 13.0, @paquete.peso.to_f
  end

  test "un cero o un vacío no es una medida" do
    assert_raises(MedirPaquete::NoSePuede) do
      MedirPaquete.new(@paquete, user: @user).medir!(peso: "0", alto: "10", largo: "12", ancho: "14")
    end
    assert_raises(MedirPaquete::NoSePuede) do
      MedirPaquete.new(@paquete, user: @user).medir!(peso: "12", alto: "", largo: "12", ancho: "14")
    end
    assert_nil @paquete.reload.medido_at
  end

  # La pre-factura copia `peso_cobrar` al crearse y no lo vuelve a leer.
  test "no se mide una caja que ya está en una pre-factura" do
    @paquete.update_columns(pre_factura_id: PreFactura.first.id)

    e = assert_raises(MedirPaquete::NoSePuede) do
      MedirPaquete.new(@paquete, user: @user).medir!(peso: "12", alto: "10", largo: "12", ancho: "14")
    end
    assert_match(/pre-factura/, e.message)
  end

  test "no se mide una caja que todavía no se recibió en Honduras" do
    @paquete.update_columns(estado: "enviado_honduras")

    e = assert_raises(MedirPaquete::NoSePuede) do
      MedirPaquete.new(@paquete, user: @user).medir!(peso: "12", alto: "10", largo: "12", ancho: "14")
    end
    assert_match(/Recibir Carga/, e.message)
  end
end
