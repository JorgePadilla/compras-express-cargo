require "application_system_test_case"

# PR-C6.24: Miami tiene que saber a qué sucursal va la caja, apenas elige el
# cliente.
#
# Yusef, 2026-08-08:
#
#   "Se me olvidó decirte algo… lo que queremos es **empacar todas las
#    sucursales en Miami por separado, en caja por separado**. Si dice
#    Tegucigalpa, es sucursal — o sea, sucursales ajenas a San Pedro."
#   "Yo opino dos cosas: una es que le salga **en rojo** 'sucursal Tegucigalpa'
#    o 'se entregará en Tegucigalpa'."
#   "Solo quiero **un modal al principio y uno al final**."
#
# Es una decisión **física**: en qué bolsa cae la caja. Por eso el aviso sale
# al elegir el cliente y no al guardar — si se entera tarde, hay que volver a
# abrir la bolsa. Contexto que dio: en Miami hay tres estaciones de etiquetado
# y bolsas separando lo digitado de lo que no; esto pide una tercera bolsa por
# sucursal.
#
# **El módulo de empaque queda fuera**: lo difirió él en esa misma reunión
# ("no sé si lo cargamos ahorita y después lo vamos a mejorar").
class EtiquetarAvisoSucursalTest < ApplicationSystemTestCase
  setup do
    # C29-03 · El aviso sale de la sucursal de retiro, nunca de la ciudad: la
    # ciudad es otra a propósito, para que un regreso al fallback se vea.
    clientes(:maria).update!(ciudad: "Choluteca", sucursal_retiro: sucursales(:humuya_tgu))

    ingresar(users(:digitador))

    abrir_sesion_etiquetar(TipoEnvio.activos.order(:nombre).first)
  end

  test "al elegir el cliente avisa a donde va" do
    elegir_cliente

    assert_selector "[data-etiquetar-target=sucursalBanner]:not(.hidden)", wait: 5
    assert_text "Se entregará en #{sucursales(:humuya_tgu).nombre}"
  end

  test "sin cliente elegido no avisa nada" do
    assert_no_selector "[data-etiquetar-target=sucursalBanner]:not(.hidden)"
  end

  test "el aviso se va al limpiar el formulario" do
    # Si quedara puesto, el siguiente bulto se guardaría en la bolsa anterior
    # — que es exactamente el error que este aviso viene a evitar.
    elegir_cliente
    assert_selector "[data-etiquetar-target=sucursalBanner]:not(.hidden)", wait: 5

    page.send_keys(:f2)

    assert_no_selector "[data-etiquetar-target=sucursalBanner]:not(.hidden)", wait: 5
  end

  test "un cliente sin sucursal de retiro avisa que falta, no su ciudad" do
    # C29-03 · Yusef, 2026-10-08: *"la ciudad donde es es una cosa y donde
    # retira es otra"*. Antes esto decía «Se entregará en Choluteca», y la
    # etiqueta, la sucursal por defecto.
    clientes(:maria).update!(sucursal_retiro: nil)

    elegir_cliente

    assert_selector "[data-etiquetar-target=sucursalBanner]:not(.hidden)", wait: 5
    assert_text "Este cliente no tiene sucursal de retiro"
    assert_no_text "Se entregará en"
    assert_no_text "Choluteca"
  end

  private

  def elegir_cliente
    campo = find("[data-etiquetar-target=clienteInput]")
    campo.click
    campo.send_keys("2")
    assert_selector "[data-index]", wait: 5
    campo.send_keys(:enter)
  end
end
