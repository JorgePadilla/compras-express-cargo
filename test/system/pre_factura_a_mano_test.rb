require "application_system_test_case"

# PR-P.10 · La puerta de las excepciones, de punta a punta: desde el índice,
# «A mano (excepciones)» → cliente → una tanda medida (UN check) → el total que
# muestra la pantalla → crear → la pre-factura cobra el volumen y guarda ese
# mismo total.
class PreFacturaAManoSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:supervisor_prefactura)
    @cliente = clientes(:juan)
    Tarifa.delete_all
    Tarifa.create!(tipo_envio: tipo_envios(:cer), precio_libra: 4.50, moneda: "USD")

    @cajas = 2.times.map do
      Paquete.create!(tracking: "1ZAMANO#{SecureRandom.hex(4).upcase}", cliente: @cliente, tipo_envio: tipo_envios(:cer),
                      sucursal_recepcion: sucursales(:miami), estado: "en_aduana", descripcion: "Zapatos", peso: 2)
    end
    @bulto, = MedirBulto.new(user: @user).guardar!(paquete_ids: @cajas.map(&:id), volumenes: [ { peso: "12" } ])

    ingresar(@user)
  end

  test "una tanda medida se elige con un check y se guarda por volumen, con el total que mostró la pantalla" do
    visit pre_facturas_path
    click_on "A mano (excepciones)"
    assert_text "Esta puerta es para las excepciones"

    select "#{@cliente.codigo} - #{@cliente.nombre_completo}", from: "cliente_id"
    click_on "Continuar"
    assert_text "Tanda medida · 2 cajas", wait: 5
    assert_text "Volumen · 12 lb"
    assert_no_selector "#paquete_#{@cajas.first.id}"
    assert_text "Marcá paquetes o tandas para ver el total."

    find("#tanda_#{@bulto.sesion}").check
    assert_selector "[data-monto=total]", wait: 5
    mostrado = find("[data-monto=total]").text

    click_on "Crear Pre-Factura"
    assert_text "creada", wait: 5

    pf = PreFactura.order(:id).last
    assert_equal @cajas.map(&:id).sort, pf.paquetes.map(&:id).sort
    assert_equal "L. #{ActiveSupport::NumberHelper.number_to_delimited(format('%.2f', pf.total))}", mostrado
    assert_text "2 cajas incluidas"
    assert_text mostrado
  end
end
