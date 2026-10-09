require "test_helper"

# PR-C6.46: la tarjeta de sección que comparten la pre-alerta de admin y la del
# portal.
class FormSectionComponentTest < ViewComponent::TestCase
  test "muestra el titulo y la bajada" do
    render_inline(FormSectionComponent.new(title: "Referencia", subtitle: "Cómo se reconoce")) { "campos" }

    assert_selector "h2", text: "Referencia"
    assert_selector "p", text: "Cómo se reconoce"
    assert_text "campos"
  end

  test "sin bajada no deja un parrafo vacio" do
    render_inline(FormSectionComponent.new(title: "Notas")) { "x" }

    assert_selector "h2", text: "Notas"
    assert_no_selector "p"
  end

  test "sin titulo no dibuja encabezado" do
    # La tarjeta de Paquetes trae su propia fila —título más el contador— así
    # que el componente no puede imponerle una.
    render_inline(FormSectionComponent.new) { "solo contenido" }

    assert_no_selector "h2"
    assert_text "solo contenido"
  end

  test "el separador del pie sale solo si hay pie" do
    # Un `border-t` colgando bajo una tarjeta sin botones se lee como si el
    # contenido estuviera cortado.
    render_inline(FormSectionComponent.new(title: "Sin pie")) { "x" }
    assert_no_selector ".border-t"

    render_inline(FormSectionComponent.new(title: "Con pie")) do |s|
      s.with_footer { "Guardar" }
      "x"
    end
    assert_selector ".border-t", text: "Guardar"
  end

  test "trae modo oscuro en fondo, borde y titulo" do
    # Sin esto la tarjeta sale blanca sobre el fondo oscuro del layout de
    # admin, que tiene toggle de tema en el header.
    render_inline(FormSectionComponent.new(title: "Referencia")) { "x" }
    clases = page.native.to_html

    assert_match(/dark:from-gray-800/, clases)
    assert_match(/dark:border-gray-700/, clases)
    assert_match(/dark:text-cec-gold/, clases, "el navy sobre oscuro da 1.69:1")
  end

  test "el titulo va navy en claro y gold en oscuro, nunca navy solo" do
    # Es la regla que `ButtonComponent` ya fijó: `text-cec-navy` sobre gris-900
    # fue el peor defecto de contraste de la auditoría.
    render_inline(FormSectionComponent.new(title: "X")) { "y" }
    titulo = page.find("h2")[:class]

    assert_includes titulo, "text-cec-navy"
    assert_includes titulo, "dark:text-cec-gold"
  end

  test "los atributos van al elemento raiz" do
    # La tarjeta de Paquetes ES el elemento de Stimulus: si el `data-controller`
    # terminara en un div de adentro, los targets del template quedarían fuera
    # de su alcance y el botón de agregar dejaría de funcionar.
    render_inline(FormSectionComponent.new(data: { controller: "pre-alerta-editor" },
                                           class: "mi-clase")) { "x" }

    assert_selector "section[data-controller='pre-alerta-editor'].mi-clase"
  end

  test "las densidades cambian el aire, no el lenguaje" do
    comoda = render_inline(FormSectionComponent.new(title: "X", densidad: :comoda)).to_html
    compacta = render_inline(FormSectionComponent.new(title: "X", densidad: :compacta)).to_html

    assert_match(/p-6 sm:p-8/, comoda)
    assert_match(/p-4 sm:p-5/, compacta)
    # Lo que NO cambia: las dos siguen siendo la misma tarjeta.
    [ comoda, compacta ].each do |html|
      assert_match(/rounded-2xl/, html)
      assert_match(/dark:text-cec-gold/, html)
    end
  end

  test "al_borde no pone padding, para que la tabla llegue al borde" do
    html = render_inline(FormSectionComponent.new(densidad: :al_borde)) { "tabla" }.to_html

    assert_match(/overflow-hidden/, html)
    assert_no_match(/\bp-4\b|\bp-6\b/, html)
  end

  test "una densidad inventada revienta en vez de caer en la default" do
    # Caer en silencio dejaría una tarjeta con el aire equivocado y nadie se
    # entera hasta que alguien mira la pantalla.
    assert_raises(KeyError) { FormSectionComponent.new(densidad: :gigante) }
  end
end
