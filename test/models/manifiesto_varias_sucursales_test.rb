require "test_helper"

# C31-09 · Un manifiesto oficial va a **varias** sucursales, y siempre a
# alguna.
#
#   > "Podés marcar acá arriba que vas a mandar a varias sucursales." · "Si
#   >  tenemos dos sucursales, Tegus y La Ceiba, muy probablemente las
#   >  empaquemos juntas, porque al final acá las vamos a separar."
#   > "Siempre debemos marcar a dónde va."
#
# En la prueba del 2026-10-12 una caja de Humuya entró en el de San Pedro
# porque el manifiesto no tenía sucursal marcada.
class ManifiestoVariasSucursalesTest < ActiveSupport::TestCase
  setup do
    @sps = sucursales(:zeron_sps)
    @tgu = sucursales(:humuya_tgu)
    @manifiesto = manifiestos(:creado)
  end

  def paquete(sucursal)
    Paquete.new(tracking: "1ZVARIAS#{SecureRandom.hex(4).upcase}", cliente: clientes(:juan), sucursal: sucursal)
  end

  test "acepta lo que retira en cualquiera de sus sucursales, y nada más" do
    @manifiesto.update!(sucursal_entrega_ids: [ @sps.id, @tgu.id ])
    assert @manifiesto.acepta_sucursal?(paquete(@tgu))
    assert @manifiesto.acepta_sucursal?(paquete(@sps))

    solo_sps = Manifiesto.find(@manifiesto.id)
    solo_sps.update!(sucursal_entrega_ids: [ @sps.id ])
    assert_not solo_sps.acepta_sucursal?(paquete(@tgu)), "uno de Humuya no entra al que va solo a San Pedro"
  end

  # *"Ahorita default San Pedro."*
  test "el que no tiene sucursal de retiro cuenta como la de por defecto" do
    @sps.update_columns(retiro_por_defecto: true)
    @manifiesto.update!(sucursal_entrega_ids: [ @tgu.id ])

    assert_not @manifiesto.acepta_sucursal?(paquete(nil)), "sin sucursal es San Pedro: no va a Humuya"

    @manifiesto.update!(sucursal_entrega_ids: [ @sps.id ])
    assert Manifiesto.find(@manifiesto.id).acepta_sucursal?(paquete(nil))
  end

  test "el oficial no se guarda sin ninguna sucursal marcada" do
    @manifiesto.sucursal_entrega_ids = []

    assert_not @manifiesto.valid?
    assert_match(/al menos una/, @manifiesto.errors.full_messages.to_sentence)
  end

  test "el interno sigue con una sola, y no compara sucursales" do
    interno = Manifiesto.create!(tipo: "interno", sucursal_origen: @sps, sucursal_entrega: @tgu,
                                 tipo_envios: [ tipo_envios(:cer) ])

    assert interno.acepta_sucursal?(paquete(@sps))
    assert_equal @tgu, interno.sucursal_de_llegada
    assert_equal "#{@tgu.nombre}", interno.sucursales_entrega_texto
  end

  # La carga de varias viaja junta y se separa en San Pedro: *"al final acá
  # las vamos a separar"*.
  test "dónde aterriza: la única, o San Pedro si van a varias" do
    @sps.update_columns(retiro_por_defecto: true)

    @manifiesto.update!(sucursal_entrega_ids: [ @tgu.id ])
    assert_equal @tgu, Manifiesto.find(@manifiesto.id).sucursal_de_llegada

    @manifiesto.update!(sucursal_entrega_ids: [ @tgu.id, @sps.id ])
    assert_equal @sps, Manifiesto.find(@manifiesto.id).sucursal_de_llegada
  end

  test "la ficha y el impreso dicen todas" do
    @manifiesto.update!(sucursal_entrega_ids: [ @tgu.id, @sps.id ])

    assert_equal [ @sps.nombre, @tgu.nombre ].sort.join(", "), Manifiesto.find(@manifiesto.id).sucursales_entrega_texto
  end

  # La 4×6 de la caja dice a dónde va **lo que lleva adentro**: *"ahí podrías
  # mandar mixto"*.
  test "el «A:» de la caja son las sucursales de sus paquetes" do
    @manifiesto.update!(sucursal_entrega_ids: [ @tgu.id, @sps.id ])
    caja = @manifiesto.cajas.create!(alto: 10, largo: 10, ancho: 10, peso: 5)
    [ @tgu, @sps ].each do |s|
      Paquete.create!(tracking: "1ZCAJAMIXTA#{SecureRandom.hex(3).upcase}", cliente: clientes(:juan), sucursal: s,
                      manifiesto: @manifiesto, caja_manifiesto: caja, estado: "empacado")
    end

    assert_equal [ @sps.nombre, @tgu.nombre ].sort.join(", "), caja.reload.sucursales_adentro
  end
end
