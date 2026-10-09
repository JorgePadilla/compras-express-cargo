require "test_helper"

# «Enviado según política», el único lugar donde se escribe ese control.
# Copia deliberada del test de RetenerMiamiComponent: mismas garantías.
class EnviadoPorPoliticaComponentTest < ViewComponent::TestCase
  def builder(objeto = Paquete.new, nombre = :paquete)
    ActionView::Helpers::FormBuilder.new(nombre, objeto, vc_test_controller.view_context, {})
  end

  def motivos = MotivoEnvioPolitica.activos.ordered.to_a

  test "los motivos salen del catálogo, uno por cada activo" do
    render_inline(EnviadoPorPoliticaComponent.new(f: builder, motivos: motivos))

    assert_selector "input[type=checkbox][name='paquete[motivo_envio_politica_ids][]']", count: motivos.size
    assert_text motivos.first.nombre
    assert_no_text "Motivo dado de baja"
  end

  test "se pueden marcar varios, no uno solo" do
    render_inline(EnviadoPorPoliticaComponent.new(f: builder, motivos: motivos))

    assert_no_selector "input[type=radio][name*='motivo_envio_politica_ids']"
  end

  test "el catálogo vacío no deja el modal mudo" do
    render_inline(EnviadoPorPoliticaComponent.new(f: builder, motivos: []))

    assert_text "No hay motivos configurados todavía"
  end

  test "nada lleva `required`" do
    render_inline(EnviadoPorPoliticaComponent.new(f: builder, motivos: motivos))

    assert_no_selector "[required]"
  end

  test "el badge de activo sale solo cuando ya venía marcado" do
    render_inline(EnviadoPorPoliticaComponent.new(f: builder, motivos: motivos))
    assert_no_text "activo"

    render_inline(EnviadoPorPoliticaComponent.new(f: builder(Paquete.new(enviado_por_politica: true)), motivos: motivos))
    assert_text "activo"
  end

  test "los motivos que ya tenía vienen marcados" do
    paquete = Paquete.new(enviado_por_politica: true, motivo_envio_politica_ids: [ motivos.first.id ])

    render_inline(EnviadoPorPoliticaComponent.new(f: builder(paquete), motivos: motivos))

    assert_selector "input[name='paquete[motivo_envio_politica_ids][]'][checked]", count: 1
  end
end
