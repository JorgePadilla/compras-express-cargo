require "application_system_test_case"

# PR: lo del bloque de cajas que solo el navegador puede ver.
#
# ⚠️ **CI no corre `test/system`.** `bin/rails test` los excluye — lo dice el
# comentario de `cajas_en_las_dos_pantallas_test.rb`, escrito cuando un bug de
# este mismo bloque llegó a staging por eso. Así que esto es una red para quien
# corra los tests a mano, no una garantía de CI. Lo que se pudo fijar sin
# navegador está en `test/controllers/caja_en_curso_test.rb`.
class CajaEnCursoTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))
    abrir_etiquetar
  end

  test "el rotulo dice que caja se esta midiendo" do
    # Es el arreglo: el bloque deja de ser anónimo. Con la lista vacía es la
    # Caja 1; después de agregar una, pasa a ser la 2.
    assert_selector "[data-cajas-repetidor-target='rotuloCaja']", text: /caja 1/i

    llenar_caja(peso: "5")
    find("[data-cajas-repetidor-target='agregarBtn']").click

    assert_selector "[data-cajas-repetidor-target='rotuloCaja']", text: /caja 2/i
    assert_selector ".caja-fila", count: 1
  end

  test "quitar una caja devuelve el rotulo" do
    llenar_caja(peso: "5")
    find("[data-cajas-repetidor-target='agregarBtn']").click
    assert_selector "[data-cajas-repetidor-target='rotuloCaja']", text: /caja 2/i

    find(".caja-fila button").click

    assert_selector "[data-cajas-repetidor-target='rotuloCaja']", text: /caja 1/i
  end

  test "guardar sin apretar Agregar no pierde la caja" do
    # La trampa que Jorge llamó "confuso": escribías peso y medidas, le dabas
    # Guardar, y con cajas ya en la lista esos datos se descartaban en silencio.
    llenar_caja(peso: "5")
    find("[data-cajas-repetidor-target='agregarBtn']").click

    # La segunda queda a medio llenar, sin apretar Agregar.
    llenar_caja(peso: "30")

    antes = Paquete.count
    find("#paquete_tracking").set("1Z999SINAGREGAR")
    elegir_cliente
    find("[data-action*='etiquetar#submitForm']", match: :first).click
    esperar { Paquete.count == antes + 2 }

    assert_equal antes + 2, Paquete.count, "la caja a medio llenar no se guardó"
    dos = Paquete.order(:id).last(2)
    assert_equal [ 5.0, 30.0 ], dos.map { |p| p.peso.to_f }.sort,
                 "la caja a medio llenar se perdió"
  end

  test "el total del envio cuenta la caja que se esta escribiendo" do
    # Jorge: "tiene malo la suma de libras para cobrar... en el panel de cálculo
    # mientras cargo". Agregaba dos y empezaba la tercera, y el total seguía
    # diciendo dos.
    llenar_caja(peso: "10")
    find("[data-cajas-repetidor-target='agregarBtn']").click
    llenar_caja(peso: "20")

    assert_selector "[data-calc-volumetrico-target='totalCajas']", text: "2"
    assert_selector "[data-calc-volumetrico-target='totalPeso']", text: "30"
  end

  test "al guardar, las cajas se limpian para el siguiente paquete" do
    # `_limpiarCampos` deja afuera los `input[type=hidden]` a propósito —ahí
    # viven el CSRF y el `_method`— y las filas de caja guardan sus valores
    # justo en hidden. Sin esto, el paquete siguiente hereda las cajas del
    # anterior: un split que nadie pidió.
    llenar_caja(peso: "5")
    find("[data-cajas-repetidor-target='agregarBtn']").click
    llenar_caja(peso: "7")
    find("[data-cajas-repetidor-target='agregarBtn']").click

    antes = Paquete.count
    find("#paquete_tracking").set("1Z999LIMPIA")
    elegir_cliente
    find("[data-action*='etiquetar#submitForm']", match: :first).click
    esperar { Paquete.count == antes + 2 }

    assert_no_selector ".caja-fila", wait: 5
    assert_selector "[data-cajas-repetidor-target='rotuloCaja']", text: /caja 1/i
  end

  test "si el guardado falla, las cajas siguen ahi" do
    # Perder tres cajas ya medidas porque faltaba el cliente sería peor que el
    # bug que este PR vino a arreglar: hay que volver a la bodega a pesarlas.
    llenar_caja(peso: "5")
    find("[data-cajas-repetidor-target='agregarBtn']").click
    llenar_caja(peso: "7")
    find("[data-cajas-repetidor-target='agregarBtn']").click

    antes = Paquete.count
    # Sin cliente el server rechaza: es el error más común de esta pantalla.
    find("#paquete_tracking").set("1Z999SINCLIENTE")
    find("[data-action*='etiquetar#submitForm']", match: :first).click
    sleep 1.5

    assert_equal antes, Paquete.count, "no debería haber guardado"
    assert_selector ".caja-fila", count: 2, wait: 5
    # Y con su resumen: una fila que vuelve del servidor sin decir cuánto pesa
    # obliga a abrirla o a re-medir, que es lo mismo que perderla.
    assert_selector ".caja-fila", text: /5 lb/
    assert_selector ".caja-fila", text: /7 lb/
  end

  test "con una sola caja no sale el panel de total" do
    # Sería el mismo número de arriba repetido en otro recuadro.
    llenar_caja(peso: "10")

    assert_selector "[data-calc-volumetrico-target='totalEnvio'].hidden", visible: :all
  end

  private

  def llenar_caja(peso:)
    find("[data-caja-campo='peso']").set(peso)
  end

  def esperar(segundos: 8)
    limite = Process.clock_gettime(Process::CLOCK_MONOTONIC) + segundos
    sleep 0.15 until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) > limite
  end

  # El autocomplete es de otra pantalla y no es lo que este test prueba: se
  # pone el id directo, que es lo que el form manda igual.
  def elegir_cliente
    page.execute_script(
      "document.querySelector('[data-etiquetar-target=clienteId]').value = arguments[0]",
      clientes(:juan).id
    )
  end


  def abrir_etiquetar
    abrir_sesion_etiquetar(TipoEnvio.activos.order(:nombre).first)
  end
end
