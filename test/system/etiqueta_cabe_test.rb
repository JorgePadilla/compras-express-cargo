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

  # C20-08: la etiqueta de Entrega Personal lleva un renglón MÁS —«PAGADO» o
  # «NO PAGADO», que Yusef pidió para esa pantalla y las recolectas—, así que
  # es la que más apretada queda. Si esta falla, se bajan los escalones; no se
  # saca el renglón, que es el que dice si hay que cobrar.
  test "la etiqueta de entrega personal, con el renglón del pago, tampoco se desborda" do
    @paquete.update!(proveedor: Proveedor.where(tipo: "entrega_personal").activos.first,
                     prepagado_miami: false)

    visit etiqueta_paquete_path(@paquete)
    assert_selector "[data-campo=pago]", visible: :all

    contenido = medir("scrollHeight")
    etiqueta  = medir("clientHeight")

    assert_operator contenido, :<=, etiqueta,
                    "con el renglón del pago se recortan #{contenido - etiqueta}px por abajo."
  end

  test "la etiqueta sin tercero ni driver tampoco se desborda" do
    @paquete.update!(tercero: nil, driver: nil, tracking_secundario: nil)

    visit etiqueta_paquete_path(@paquete)

    assert_operator medir("scrollHeight"), :<=, medir("clientHeight")
  end

  # C25-07 · **Este test decía lo contrario.** Su comentario afirmaba que el
  # recorte con puntos suspensivos era lo deseado. Yusef vio *"Sofía García…
  # Jorge Alejandro Federico"* y pidió lo otro: *"para que aquí te quepa el
  # nombre completo y ese nombre se ajuste el tamaño"*. Ahora el nombre va solo
  # en su fila, con `data-ajustar`: **se achica, no se corta**. Y el tercero se
  # fue a otro renglón — el del número de recepción.
  test "un nombre largo se achica en vez de cortarse, y no empuja el resto" do
    # 40 caracteres: bastante más que el «Jorge Alejandro Federico» que Yusef
    # vio cortado, y lo que de verdad se puede leer a 6 pt en 2.1 pulgadas.
    @paquete.cliente.update!(nombre: "MARIA DE LOS ANGELES", apellido: "HERNANDEZ RODRIGUEZ")

    visit etiqueta_paquete_path(@paquete)

    nombre = page.evaluate_script(<<~JS)
      (function () {
        var el = document.querySelector("[data-campo=cliente_nombre]");
        var t = document.querySelector("[data-campo=tercero]");
        return [ el.scrollWidth, el.clientWidth, parseFloat(getComputedStyle(el).fontSize),
                 el.offsetTop, t ? t.offsetTop : null, el.textContent.trim() ];
      })()
    JS

    assert_operator nombre[0], :<=, nombre[1],
                    "\"#{nombre[5]}\" se está recortando: necesita #{nombre[0]}px y tiene #{nombre[1]}px"
    assert_operator nombre[2], :<, 9.5 * 96 / 72, "tendría que haberse achicado de los 9.5 pt"
    assert_not_nil nombre[4], "la muestra lleva tercero"
    # En **otro** renglón — no «abajo»: Yusef dijo abajo, se probó literal y
    # desbordaba 8 px; quedó arriba, al lado del número de recepción (ver
    # `definicion.rb`). Lo que importa es que ya no comparte fila con el nombre.
    assert_not_equal nombre[3], nombre[4], "el tercero no puede compartir renglón con el nombre"
    assert_operator medir("scrollHeight"), :<=, medir("clientHeight")
  end

  # Y el piso es el piso. Un nombre de 50 caracteres no cabe en 2.1 pulgadas
  # ni a 6 pt: ahí el ajuste **para en 6** y deja que el `overflow: hidden`
  # recorte, en vez de seguir bajando a algo que no se lee. La primera versión
  # del script se pasaba del piso (comparaba antes de restar).
  test "un nombre imposible toca el piso y no baja de ahí" do
    @paquete.cliente.update!(nombre: "MARIA DE LOS ANGELES", apellido: "HERNANDEZ RODRIGUEZ DE SAMARA Y CASTRO")

    visit etiqueta_paquete_path(@paquete)

    pt = page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('[data-campo=cliente_nombre]')).fontSize) * 72 / 96")
    assert_in_delta 6, pt, 0.05, "el piso es 6 pt: ni más chico, ni un pelo más"
  end

  # Un nombre corto **no** se achica: 9.5 pt es el máximo y ahí se queda.
  test "un nombre corto se queda en su tamaño" do
    @paquete.cliente.update!(nombre: "Ana", apellido: "Paz")

    visit etiqueta_paquete_path(@paquete)

    pt = page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('[data-campo=cliente_nombre]')).fontSize) * 72 / 96")
    assert_in_delta 9.5, pt, 0.3
  end

  # Y el tercero, en su renglón nuevo, tampoco se corta en la etiqueta más
  # llena — entrega personal con NO PAGADO, driver y tracking secundario. Se
  # probaron tres sitios antes de éste, con medidas (ver `definicion.rb`).
  test "el tercero cabe entero en su renglón" do
    @paquete.update!(proveedor: Proveedor.where(tipo: "entrega_personal").activos.first,
                     prepagado_miami: false, tercero: clientes(:maria))

    visit etiqueta_paquete_path(@paquete)

    t = page.evaluate_script("(function(){var el=document.querySelector('[data-campo=tercero]');return [el.scrollWidth, el.clientWidth, el.textContent.trim()];})()")
    assert_operator t[0], :<=, t[1], "\"#{t[2]}\" se está recortando en su renglón"
  end

  # El "¿qué es San Pedro Soda?" fue exactamente esto: la sucursal saliendo
  # cortada. Ya se truncó dos veces al agregar campos a su derecha —el tipo de
  # envío completo y después el código del proveedor—, así que va como test y
  # no como cosa a revisar de vista.
  test "la sucursal donde retira nunca sale truncada" do
    # El caso largo, que es el que importa. C25-08: sin sucursal en el paquete
    # ya **no** cae a la ciudad del cliente sino a la sucursal de retiro por
    # defecto — Yusef: *"tiene que decir Zerón SPS, así se llama la sucursal"*.
    # Se le da un nombre largo a propósito, que es lo que este test cuida.
    @paquete.update!(sucursal: nil)
    Sucursal.update_all(retiro_por_defecto: false)
    sucursales(:zeron_sps).update!(retiro_por_defecto: true)

    visit etiqueta_paquete_path(@paquete)

    recorte = page.evaluate_script(<<~JS)
      (function () {
        var el = document.querySelector("[data-campo=sucursal]");
        return [ el.scrollWidth, el.clientWidth, el.textContent.trim() ];
      })()
    JS

    assert_operator recorte[0], :<=, recorte[1],
                    "\"#{recorte[2]}\" no entra: necesita #{recorte[0]}px y tiene #{recorte[1]}px. " \
                    "Algo a su derecha le esta robando ancho."
    # C25-08 · Y dice **la sucursal**, no la ciudad. La primera versión de este
    # test solo medía ancho, y «Tegucigalpa» también cabe: pasaba con el
    # fallback viejo puesto. Un test que no distingue el bug no es un test.
    assert_includes recorte[2], sucursales(:zeron_sps).nombre,
                    "sin sucursal en el paquete tiene que caer a la de retiro por defecto"
    assert_not_includes recorte[2], @paquete.cliente.ciudad.to_s,
                        "la ciudad del cliente ya no es el fallback: con dos sucursales en la misma ciudad no dice dónde"
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

  def medir(propiedad)
    page.evaluate_script("document.querySelector('.etq').#{propiedad}")
  end
end
