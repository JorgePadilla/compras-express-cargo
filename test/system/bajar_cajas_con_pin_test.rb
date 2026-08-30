require "application_system_test_case"

# PR-C6.42 · RP-18: el modal que el supervisor usa para destrabar un split con
# cajas de más.
#
# Todo lo demás de este PR se prueba del lado del servidor. Esto no: si el
# controller de Stimulus no queda registrado, o el botón no está adentro de su
# scope, la suite entera sigue verde y **el botón está muerto en staging**. Es
# exactamente la clase de falla que los system tests de este proyecto existen
# para agarrar.
class BajarCajasConPinSistemaTest < ApplicationSystemTestCase
  setup do
    @supervisor = users(:admin)
    @supervisor.update!(pin: "1234")

    @cajas = crear_split(2)
    # La caja 2 ya entró a cobro: sin PIN, el sistema no la deja bajar.
    @cajas.last.update_columns(estado: "pre_facturado")

    ingresar(@supervisor)
  end

  test "el supervisor baja la cantidad desde el modal" do
    visit paquete_path(@cajas.first)

    click_on "Bajar la cantidad de cajas"
    assert_selector "dialog[open]", wait: 5

    within "dialog[open]" do
      fill_in "pin", with: "1234"
      click_on "Bajar la cantidad"
    end

    assert_text "Quedaron 1 caja", wait: 5
    assert_equal 0, Paquete.where(id: @cajas.last.id).count
  end

  test "con el PIN equivocado no borra nada y lo dice" do
    visit paquete_path(@cajas.first)

    click_on "Bajar la cantidad de cajas"
    within "dialog[open]" do
      fill_in "pin", with: "9999"
      click_on "Bajar la cantidad"
    end

    assert_text "PIN incorrecto", wait: 5
    assert_equal 2, Paquete.where(numero_recepcion: @cajas.first.numero_recepcion).count
  end

  test "el modal arranca cerrado" do
    visit paquete_path(@cajas.first)

    assert_no_selector "dialog[open]"
  end

  private

  def crear_split(n)
    Paquete.crear_split!(
      attrs: {
        tracking: "SYS#{SecureRandom.hex(4)}",
        cliente: clientes(:juan),
        sucursal_recepcion: sucursales(:miami),
        estado: "empacado",
        descripcion: "Split de prueba",
        user: users(:digitador)
      },
      total_cajas: n
    )
  end
end
