require "application_system_test_case"

# PR-C6.27: los trackings se imprimen completos.
#
# Yusef mandó la etiqueta impresa anotada en rojo. Un recuadro sobre cada
# tracking, y arriba de todo la regla:
#
#   "LOS TRACKING DEBEN CABER COMPLETOS"
#
# En la foto se ve por qué: el secundario salía cortado con `...` a mitad de
# número. La causa no eran datos faltantes sino CSS — `.t` lleva
# `text-overflow: ellipsis`, y tracking y secundario iban **concatenados con
# " · " adentro de un solo `.t`**, así que lo que se recortaba era siempre el
# final del segundo.
#
# Un nombre largo recortado todavía se entiende. Un tracking recortado no
# sirve para nada: no se compara contra la caja ni se teclea en el sitio del
# carrier.
#
# Va como system test porque el recorte es de CSS: en el HTML el número sale
# entero igual, y ningún test de Rails ve la diferencia.
class EtiquetaTrackingsCompletosTest < ApplicationSystemTestCase
  # El par de la foto: el código completo que escupe la pistola de USPS, que es
  # lo más largo que puede caer en esa línea.
  LARGO = "420331439261091390000806743500382574".freeze

  setup do
    ingresar(users(:digitador))
    @paquete = paquetes(:disponible_entrega_juan)
  end

  test "el tracking secundario mas largo entra entero" do
    @paquete.update!(tracking: "9261091390000806743500382574", tracking_secundario: LARGO)

    visit etiqueta_paquete_path(@paquete)

    assert_entra "[data-campo=tracking]"
    assert_entra "[data-campo=tracking-secundario]"
  end

  test "un tracking mas largo que la etiqueta se parte, no se corta" do
    # A 7pt el de USPS entra justo en una línea (198px de 205), así que ese
    # caso lo resuelve el tamaño de letra solo. Este es el otro seguro: con un
    # valor que no entra ni así, `.trk` lo baja a una segunda línea en vez de
    # comérselo con `…`.
    largo = "4203314392610913900008067435003825741Z999AA10123456784"
    @paquete.update!(tracking_secundario: largo)

    visit etiqueta_paquete_path(@paquete)

    assert_entra "[data-campo=tracking-secundario]"
    assert_operator alto("[data-campo=tracking-secundario]"), :>,
                    alto("[data-campo=tracking]"),
                    "no se partió en dos líneas: se está recortando"
  end

  test "cada tracking va en su propia linea" do
    # Concatenados en un solo elemento, el recorte se come el segundo entero.
    @paquete.update!(tracking: "1Z999AA10123456784", tracking_secundario: LARGO)

    visit etiqueta_paquete_path(@paquete)

    assert_selector "[data-campo=tracking]", visible: :all
    assert_selector "[data-campo=tracking-secundario]", visible: :all
    assert_equal LARGO, texto("[data-campo=tracking-secundario]")
  end

  test "sin secundario no se imprime una linea vacia" do
    @paquete.update!(tracking_secundario: nil)

    visit etiqueta_paquete_path(@paquete)

    assert_no_selector "[data-campo=tracking-secundario]", visible: :all
  end

  private

  # Un texto "entra" cuando lo que el navegador dibujó no es más ancho que la
  # caja que lo contiene.
  #
  # Se mide con un `Range` sobre el texto, **no** con `scrollWidth`: con
  # `overflow:hidden` el navegador reporta el ancho ya recortado, así que
  # `scrollWidth == clientWidth` incluso cuando el `ellipsis` se está comiendo
  # media línea. Es la misma trampa que documenta `etiqueta_cabe_test` para el
  # alto. El rect del `Range` sí devuelve la extensión real del texto.
  def assert_entra(selector)
    medidas = page.evaluate_script(<<~JS)
      (function () {
        var el = document.querySelector("#{selector}");
        if (!el) return null;
        var rango = document.createRange();
        rango.selectNodeContents(el);
        return {
          texto_px: rango.getBoundingClientRect().width,
          caja_px: el.clientWidth,
          texto: el.textContent.trim()
        };
      })()
    JS

    assert medidas, "no se encontró #{selector} en la etiqueta"
    # Medio píxel de tolerancia: el rect del Range es fraccionario y
    # `clientWidth` viene redondeado a entero.
    assert_operator medidas["texto_px"], :<=, medidas["caja_px"] + 0.5,
                    "«#{medidas['texto']}» mide #{medidas['texto_px'].round(1)}px en una caja de " \
                    "#{medidas['caja_px']}px y se imprime cortado. " \
                    "Los trackings tienen que caber completos."
  end

  def texto(selector)
    page.evaluate_script("document.querySelector('#{selector}').textContent.trim()")
  end

  def alto(selector)
    page.evaluate_script("document.querySelector('#{selector}').offsetHeight")
  end
end
