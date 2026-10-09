require "test_helper"

# El bloque de peso, medidas, cajas y cálculo — `PR-C7.17`.
#
# Existe como componente porque el partial que reemplaza se rompió por un
# default: `modo_cajas = :plantilla unless defined?(modo_cajas)` no asigna nunca
# (el parser de Ruby ya definió la variable cuando evalúa el `defined?`), y
# `/etiquetar` quedó sin campo de cajas y sin poder dividir un paquete.
#
# Un `initialize` de kwargs no se puede confundir con "definido pero nil".
class CajasPesoMedidasComponentTest < ViewComponent::TestCase
  # Se arma el form builder a mano: es lo único que el componente necesita, y
  # envolverlo en un `form_with` no aporta nada a lo que se está probando.
  def builder
    ActionView::Helpers::FormBuilder.new(:paquete, Paquete.new, vc_test_controller.view_context, {})
  end

  def render_componente(**opciones)
    render_inline(CajasPesoMedidasComponent.new(f: builder, **opciones))
  end

  test "los defaults son de verdad: sin pasarlos, el componente se arma igual" do
    render_componente

    assert_selector "[data-controller~='calc-volumetrico']"
    assert_selector "[data-controller~='cajas-repetidor']"
  end

  # El bug entero, dicho como test: la única forma de dividir un paquete tiene
  # que estar en pantalla.
  test "siempre trae el boton de agregar caja" do
    render_componente

    assert_text "Agregar caja"
    assert_selector "[data-cajas-repetidor-target='lista']"
    # `visible: :all` porque un <template> no se pinta: es el molde de las filas.
    assert_selector "template[data-cajas-repetidor-target='template']", visible: :all
  end

  test "el panel de cobro esta apagado por default" do
    render_componente

    assert_no_selector "[data-controller~='cotizador']"
    assert_no_text "Valor a pagar"
  end

  test "se prende con valor_a_pagar, que es lo que hace Entrega Personal" do
    render_componente(valor_a_pagar: true, cotizador_url: "/cotizador")

    assert_selector "[data-controller~='cotizador']"
    assert_selector "[data-cotizador-url-value='/cotizador']"
    assert_text "Valor a pagar"
  end

  # PR-C6.41: el trato de solo-volumétrico es por cliente Y por servicio, y el
  # JS lo necesita para no mostrar un peso que la pre-factura no va a cobrar.
  test "le pasa el tipo de envio al calculador" do
    render_componente(tipo_envio_id: 42)

    assert_selector "[data-calc-volumetrico-tipo-envio-id-value='42']"
  end

  # Agregar o quitar una caja cambia el total; sin este cableado el panel se
  # quedaba con el peso de la caja anterior.
  test "el cambio de cajas dispara el recalculo" do
    render_componente

    assert_selector "[data-action*='cajas-repetidor:cambio->calc-volumetrico#recalcular']"
  end

  test "y tambien el recotizado cuando hay panel de cobro" do
    render_componente(valor_a_pagar: true, cotizador_url: "/cotizador")

    assert_selector "[data-action*='cajas-repetidor:cambio->cotizador#cotizar']"
  end

  test "el total del envio nace escondido: aparece cuando hay cajas" do
    render_componente

    assert_selector "[data-calc-volumetrico-target='totalEnvio'].hidden", visible: :all
    assert_selector "[data-calc-volumetrico-target='totalPeso']"
  end
end
