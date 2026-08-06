require "application_system_test_case"

# PR-10.d.2: ¿entran los 11 campos en 2.25 × 1.25 in?
#
# Es la única pregunta de la etiqueta que ningún test de Rails puede contestar:
# `.etq` tiene alto fijo y `overflow:hidden`, así que cuando el contenido se
# pasa **se recorta en silencio** — el HTML sale completo y la impresora tira
# una etiqueta sin la última línea.
#
# `scrollHeight` sí reporta el alto real del contenido aunque esté recortado,
# así que abriendo la etiqueta en Chrome de verdad se puede medir.
#
# Yusef pidió que vayan los 11 campos y que el tamaño de la etiqueta no cambie.
# Si este test falla, lo que se baja son los escalones `--t1 … --t7` del layout,
# no la cantidad de campos.
class EtiquetaCabeTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))
    @paquete = paquetes(:disponible_entrega_juan)
    # El caso que más campos lleva: tercero, driver y tracking secundario a la
    # vez. Un paquete de Entrega Personal los trae todos, así que no es un
    # borde inventado.
    @paquete.update!(
      tracking_secundario: "TBA333187639911-2",
      driver: "MARVIN LOPEZ HERNANDEZ",
      tercero: clientes(:maria)
    )
  end

  test "la etiqueta con todos los campos no se desborda" do
    visit etiqueta_paquete_path(@paquete)

    contenido = medir("scrollHeight")
    etiqueta  = medir("clientHeight")

    assert_operator contenido, :<=, etiqueta,
                    "el contenido mide #{contenido}px y la etiqueta #{etiqueta}px — " \
                    "se estan recortando #{contenido - etiqueta}px por abajo. " \
                    "Baja los escalones --t1..--t7 en layouts/etiqueta.html.erb."
  end

  test "la etiqueta sin tercero ni driver tampoco se desborda" do
    @paquete.update!(tercero: nil, driver: nil, tracking_secundario: nil)

    visit etiqueta_paquete_path(@paquete)

    assert_operator medir("scrollHeight"), :<=, medir("clientHeight")
  end

  test "un nombre largo no empuja el resto fuera de la etiqueta" do
    # Los campos de ancho variable se recortan con puntos suspensivos; si
    # alguno pudiera envolver a dos renglones, se comeria una linea.
    @paquete.cliente.update!(
      nombre: "MARIA DE LOS ANGELES", apellido: "HERNANDEZ RODRIGUEZ DE SAMARA"
    )

    visit etiqueta_paquete_path(@paquete)

    assert_operator medir("scrollHeight"), :<=, medir("clientHeight")
  end

  test "el tipo de envio es el texto mas grande de la etiqueta" do
    # La jerarquía de Yusef: "lo más importante es lo que se lee primero". Si
    # alguien reordena los escalones, esto lo agarra.
    visit etiqueta_paquete_path(@paquete)

    tipo = page.evaluate_script(<<~JS)
      (function () {
        var mayor = 0;
        document.querySelectorAll(".etq *").forEach(function (el) {
          if (!el.textContent.trim()) return;
          var px = parseFloat(getComputedStyle(el).fontSize);
          if (px > mayor) mayor = px;
        });
        var envio = document.querySelector("[data-campo=tipo-envio]");
        return [ mayor, parseFloat(getComputedStyle(envio).fontSize) ];
      })()
    JS

    assert_equal tipo[0], tipo[1],
                 "el tipo de envio tiene que ser el texto mas grande de la etiqueta"
  end

  private

  # Los system tests no comparten la sesión de los de integración: hay que
  # pasar por el formulario.
  def ingresar(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password123"
    click_on "Iniciar Sesion"
    assert_no_current_path new_session_path, wait: 5
  end

  def medir(propiedad)
    page.evaluate_script("document.querySelector('.etq').#{propiedad}")
  end
end
