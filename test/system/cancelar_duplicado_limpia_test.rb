require "application_system_test_case"

# C29-02 · «Cancelar» en *«Tracking ya existe»* limpia el tracking.
#
# Yusef, 2026-10-08: *"le doy cancelar y me deja el tracking aquí. Te lo tiene
# que limpiar"*. Lo mostró en vivo: el tracking era de Sofía, canceló, y el
# formulario lo dejó seguir y ponérselo a Diego — *"esos son errores que nos
# pasan en Miami con cualquier sistema"*.
#
# System test porque el modal lo abre el `fetch` del blur.
class CancelarDuplicadoLimpiaTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))
    abrir_sesion_etiquetar(TipoEnvio.activos.order(:nombre).first)

    @existente = Paquete.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                                 tracking: "1ZCANCELARLIMPIA", descripcion: "x",
                                 estado: "recibido_miami", user: users(:digitador),
                                 sucursal_recepcion: sucursales(:miami))
  end

  test "cancelar deja el tracking vacío y el cursor ahí" do
    visit etiquetar_path
    find("#paquete_tracking").set(@existente.tracking)
    find("#paquete_descripcion").click
    assert_selector "[data-etiquetar-target='duplicateModal']:not(.hidden)", wait: 5

    within("[data-etiquetar-target='duplicateModal']") { click_on "Cancelar" }

    assert_no_selector "[data-etiquetar-target='duplicateModal']:not(.hidden)"
    assert_equal "", find("#paquete_tracking").value
    assert_equal "paquete_tracking", page.evaluate_script("document.activeElement.id")
  end

  test "y el mismo tracking, escaneado otra vez, vuelve a preguntar" do
    # Si el memo de la consulta quedara puesto, el segundo pip no consultaría y
    # el duplicado pasaría callado: el mismo hueco por la puerta de atrás.
    visit etiquetar_path
    find("#paquete_tracking").set(@existente.tracking)
    find("#paquete_descripcion").click
    assert_selector "[data-etiquetar-target='duplicateModal']:not(.hidden)", wait: 5
    within("[data-etiquetar-target='duplicateModal']") { click_on "Cancelar" }
    assert_no_selector "[data-etiquetar-target='duplicateModal']:not(.hidden)"

    find("#paquete_tracking").set(@existente.tracking)
    find("#paquete_descripcion").click

    assert_selector "[data-etiquetar-target='duplicateModal']:not(.hidden)", wait: 5
  end
end
