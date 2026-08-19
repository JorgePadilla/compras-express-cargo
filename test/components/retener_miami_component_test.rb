require "test_helper"

# «Retener en Miami», el único lugar donde se escribe ese control.
#
# Jorge, sobre `/pre_alertas/new`: *"debería ser el mismo componente"*. No
# existía: había cuatro pantallas y cuatro respuestas, y una de ellas
# —`/entrega_personal`— no tenía nada aunque su controller estaba cableado para
# eso desde siempre.
#
# Acá se prueba **lo que sale renderizado**, no el código fuente. El lint mira el
# archivo y eso alcanza para "¿lo usan todas?", pero no para "¿los motivos se
# pueden marcar de a varios?" — y esa diferencia importa: un `radio` en vez de un
# `checkbox` deja pasar un solo motivo y el lint ni se entera.
class RetenerMiamiComponentTest < ViewComponent::TestCase
  def builder(objeto = Paquete.new, nombre = :paquete)
    ActionView::Helpers::FormBuilder.new(nombre, objeto, vc_test_controller.view_context, {})
  end

  def motivos = MotivoRetencion.activos.ordered.to_a

  test "los motivos salen del catálogo, uno por cada activo" do
    render_inline(RetenerMiamiComponent.new(f: builder, motivos: motivos))

    assert_selector "input[type=checkbox][name='paquete[motivo_retencion_ids][]']",
                    count: motivos.size
    assert_text motivos.first.nombre
  end

  test "se pueden marcar varios, no uno solo" do
    # Yusef los pidió multi-select. Con radios entraría un motivo por paquete, y
    # el caso típico —"llegó abierto **y** es perecedero"— no se podría anotar.
    render_inline(RetenerMiamiComponent.new(f: builder, motivos: motivos))

    assert_no_selector "input[type=radio][name*='motivo_retencion_ids']"
  end

  test "el catálogo vacío no deja el modal mudo" do
    render_inline(RetenerMiamiComponent.new(f: builder, motivos: []))

    assert_text "No hay motivos configurados todavía"
    assert_no_selector "input[name='paquete[motivo_retencion_ids][]']"
  end

  test "nada lleva `required`" do
    # Vive adentro de un `<dialog>` cerrado, y un control obligatorio dentro de un
    # contenedor oculto hace que Chrome se niegue a enviar el formulario **sin
    # decir por qué** — la trampa que quedó anotada en `#306`.
    render_inline(RetenerMiamiComponent.new(f: builder, motivos: motivos))

    assert_no_selector "[required]"
  end

  test "sirve igual anidado, que es para lo que se extrajo" do
    # El renglón de una pre-alerta arma los nombres anidados. Si el componente
    # los escribiera a mano —como hacían las dos copias— no se podría compartir.
    f = ActionView::Helpers::FormBuilder.new(
      "pre_alerta[pre_alerta_paquetes_attributes][0]", PreAlertaPaquete.new,
      vc_test_controller.view_context, {}
    )

    render_inline(RetenerMiamiComponent.new(f: f, motivos: motivos))

    assert_selector "input[name='pre_alerta[pre_alerta_paquetes_attributes][0][retener_miami]']"
    assert_selector "input[name='pre_alerta[pre_alerta_paquetes_attributes][0][motivo_retencion_ids][]']",
                    count: motivos.size
  end

  test "el badge de activo sale solo cuando ya venía retenido" do
    render_inline(RetenerMiamiComponent.new(f: builder, motivos: motivos))
    assert_no_text "activo"

    render_inline(RetenerMiamiComponent.new(f: builder(Paquete.new(retener_miami: true)),
                                            motivos: motivos))
    assert_text "activo"
  end

  test "los motivos que ya tenía vienen marcados" do
    paquete = Paquete.new(retener_miami: true, motivo_retencion_ids: [ motivos.first.id ])

    render_inline(RetenerMiamiComponent.new(f: builder(paquete), motivos: motivos))

    assert_selector "input[name='paquete[motivo_retencion_ids][]'][checked]", count: 1
  end
end
