require "application_system_test_case"

# C30-09 · /recibir-carga con la pistola en la lista, en Chrome.
#
#   > **Yusef:** "A veces vamos a recibir tres manifiestos de un solo y hay que
#   >  estar seleccionando cada manifiesto, entonces solo crear un search…"
#   > "Algo como lo que hiciste de medición, algo que te vaya diciendo cuál
#   >  quedó pendiente… si 7 cajas iban 6 nada más, falta una."
#
# Lo que el JSON no prueba: que la fila de **su** manifiesto se repinte sin
# recargar, que el foco se quede en la pistola entre pip y pip, y que la caja
# que completa suene a `completo` y no al pip de siempre.
class RecibirVariosManifiestosTest < ApplicationSystemTestCase
  setup do
    @uno = enviado("MRSV000001")
    @dos = enviado("MRSV000002")
    @a1 = @uno.cajas.create!(peso: 10)
    @b1 = @uno.cajas.create!(peso: 10)
    @a2 = @dos.cajas.create!(peso: 10)
    # *"Los de prefactura, ellos son los que se encargan de recibir carga"*
    # (C21-07). Con el cajero, que también recibe, Chrome dejaba de entregarle
    # las teclas a la página al segundo de cargar —en cualquier pantalla, no
    # solo en esta—, y eso es otro asunto.
    ingresar(users(:supervisor_prefactura))
    visit recepcion_carga_index_path
    esperar_la_pistola
  end

  # Sin esto el primer test de la corrida —el que paga el arranque en frío—
  # tecleaba antes de que Stimulus conectara: el Enter caía en un campo sin
  # nadie que lo escuchara y la caja no se escaneaba.
  def esperar_la_pistola
    page.document.synchronize(10) do
      conectado = page.evaluate_script(<<~JS)
        (() => {
          const el = document.querySelector("[data-controller~='recepcion-carga']")
          return !!(el && window.Stimulus?.getControllerForElementAndIdentifier(el, "recepcion-carga"))
        })()
      JS
      raise Capybara::ExpectationNotMet, "la pistola no conectó" unless conectado
    end
  end

  def enviado(numero)
    Manifiesto.create!(numero: numero, estado: "enviado", tipo_envio: "AEREO", fecha_enviado: 1.day.ago,
                       sucursal_origen: sucursales(:miami), user: users(:admin),
                       tipo_envios: [ tipo_envios(:cer) ])
  end

  def escanear(codigo) = find("#codigo_caja").send_keys(codigo, :enter)

  def fila(manifiesto) = "[data-manifiesto-fila='#{manifiesto.id}']"

  def foco = page.evaluate_script("document.activeElement.id")

  # Los sonidos se oyen por evento: se anotan los que suben hasta el documento.
  def espiar_sonidos
    page.execute_script(<<~JS)
      window.__sonidos = []
      for (const ev of ["ok", "completo", "yaRecibida", "noEsDeAqui"]) {
        document.addEventListener(`recepcion-carga:${ev}`, () => window.__sonidos.push(ev))
      }
    JS
  end

  def sonidos = page.evaluate_script("window.__sonidos")

  test "cada caja repinta la fila de su manifiesto, y la pistola no suelta el foco" do
    espiar_sonidos

    escanear(@a2.codigo)
    assert_selector "#{fila(@dos)} [data-progreso-texto]", text: "1 de 1 · completo", wait: 5
    assert_text "Caja A de MRSV000002 recibida"

    escanear(@a1.codigo)
    assert_selector "#{fila(@uno)} [data-progreso-texto]", text: "1 de 2 · falta 1", wait: 5
    assert_selector "#{fila(@uno)} [data-progreso-faltan]", text: "Falta: B"
    assert_equal "codigo_caja", foco, "el foco vuelve a la pistola"

    assert_equal %w[completo ok], sonidos
  end

  test "repetir una caja avisa que ya fue recibida, con su sonido" do
    escanear(@a1.codigo)
    assert_selector "#{fila(@uno)} [data-progreso-texto]", text: "1 de 2", wait: 5
    espiar_sonidos

    escanear(@a1.codigo)

    assert_text "La caja A de MRSV000001 ya estaba recibida", wait: 5
    assert_equal %w[yaRecibida], sonidos
  end

  test "lo que no es de ningún pendiente suena a error" do
    espiar_sonidos

    escanear("NADA-QUE-VER")

    assert_text "no es de ningún manifiesto pendiente", wait: 5
    assert_equal %w[noEsDeAqui], sonidos
  end

  test "completar un manifiesto suena a completo y no lo cierra solo" do
    escanear(@a1.codigo)
    assert_selector "#{fila(@uno)} [data-progreso-texto]", text: "1 de 2", wait: 5
    espiar_sonidos

    escanear(@b1.codigo)

    assert_selector "#{fila(@uno)} [data-progreso-texto].text-cec-teal:not(.text-gray-900)", text: "2 de 2 · completo", wait: 5
    assert_equal %w[completo], sonidos
    assert_equal "en_aduana", @uno.reload.estado
  end

  # *"Lo voy a querer imprimir para darle al oficio."* Se mira el link y no se
  # aprieta: abrir el diálogo de impresión en el Chrome de test no prueba nada.
  test "cada fila imprime su manifiesto en pestaña nueva" do
    link = find("#{fila(@dos)} a", text: "Imprimir")

    assert_equal "_blank", link[:target]
    assert_includes link[:href], documento_recepcion_carga_path(@dos)
    assert_includes link[:href], "print=true"
  end
end
