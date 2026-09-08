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

  # C26-18 · Yusef, el 2026-09-07: *"a veces no se mide, cuando es una cajita
  # bien pequeñita. Pero siempre una de estas cuatro se mete —que sería peso en
  # ese caso—, o estas tres, o esta, o todo, para que el sistema diga cuál es el
  # mayor"*. Antes esto reventaba y la caja chiquita no se podía medir.
  test "una cajita a la que solo se le pone el peso sí se mide" do
    MedirPaquete.new(@paquete, user: @user).medir!(peso: "2.5", alto: "", largo: "", ancho: "")

    @paquete.reload
    assert_equal 2.5, @paquete.peso.to_f
    assert_equal "SP", @paquete.medido_por
    assert_not_nil @paquete.medido_at
  end

  # El cero es «no lo puse», no «pesa cero»: la báscula chiquita no llega.
  test "solo las tres medidas, sin peso, también es una medida" do
    MedirPaquete.new(@paquete, user: @user).medir!(peso: "0", alto: "10", largo: "12", ancho: "14")

    @paquete.reload
    assert_equal [ 10.0, 12.0, 14.0 ], [ @paquete.alto, @paquete.largo, @paquete.ancho ].map(&:to_f)
    assert_not_nil @paquete.medido_at
  end

  # Lo que Miami digitó no se pisa con nada: un campo en blanco no es un dato.
  test "lo que se deja en blanco se queda con lo que traía de Miami" do
    @paquete.update!(peso: 3, alto: 5, largo: 6, ancho: 7)

    MedirPaquete.new(@paquete, user: @user).medir!(peso: "9", alto: "", largo: "", ancho: "")

    @paquete.reload
    assert_equal 9.0, @paquete.peso.to_f
    assert_equal [ 5.0, 6.0, 7.0 ], [ @paquete.alto, @paquete.largo, @paquete.ancho ].map(&:to_f),
                 "las medidas de Miami siguen ahí"
  end

  test "dos de tres medidas no es una medida: sin volumétrico no hay nada que comparar" do
    e = assert_raises(MedirPaquete::NoSePuede) do
      MedirPaquete.new(@paquete, user: @user).medir!(peso: "12", alto: "", largo: "12", ancho: "14")
    end
    assert_match(/las tres/, e.message)
    assert_nil @paquete.reload.medido_at
  end

  test "los cuatro en blanco no es una medida" do
    e = assert_raises(MedirPaquete::NoSePuede) do
      MedirPaquete.new(@paquete, user: @user).medir!(peso: "", alto: "", largo: "", ancho: "")
    end
    assert_match(/al menos el peso/, e.message)
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

  # C27-14 · Yusef: *"debe dejar que sí se lo salten, porque a veces se capean,
  # algunos se los van a capear"* — *"hay que poner una opción ahí"*.
  test "con el permiso puesto sí se mide, y queda sellado quién se lo saltó" do
    @paquete.update_columns(estado: "enviado_honduras")

    MedirPaquete.new(@paquete, user: @user, saltar_manifiesto: true)
                .medir!(peso: "12", alto: "10", largo: "12", ancho: "14")

    @paquete.reload
    assert_equal 12.0, @paquete.peso.to_f
    assert_equal "SP", @paquete.salto_manifiesto_por
    assert_not_nil @paquete.salto_manifiesto_at
    assert_equal "enviado_honduras", @paquete.salto_manifiesto_estado
    assert_equal "enviado_honduras", @paquete.estado,
                 "saltarse el manifiesto no le inventa un paso de aduana al paquete"
  end

  test "el permiso no sella nada cuando la caja sí pasó por el manifiesto" do
    MedirPaquete.new(@paquete, user: @user, saltar_manifiesto: true).medir!(peso: "12")

    assert_nil @paquete.reload.salto_manifiesto_at
  end

  # El otro portón sigue cerrado: ahí el peso se congeló y medirlo mentiría.
  test "el permiso no abre la puerta de la pre-factura" do
    @paquete.update_columns(estado: "enviado_honduras", pre_factura_id: pre_facturas(:borrador_juan).id)

    e = assert_raises(MedirPaquete::NoSePuede) do
      MedirPaquete.new(@paquete, user: @user, saltar_manifiesto: true).medir!(peso: "12")
    end
    assert_match(/pre-factura/, e.message)
  end
end
