require "application_system_test_case"

# PR: el modal "Sonidos de escaneo" (`RP-20`).
#
# Jorge, de oído: *"el modal suena distinto de los reales; los del sistema están
# bien, hay que arreglar los del modal"*. La causa era que la lista de botones
# estaba escrita a mano en el ERB y se había separado del cableado: el botón
# rotulado "Pre-alerta" tocaba `notify` —que es el «ya existía»— y
# `speakPreAlerta`, el sonido de verdad, no tenía botón.
#
# El lint de `test/lint/sonidos_cableados_test.rb` fija que las dos listas
# coincidan. Esto fija lo otro: que el modal **abra y se vea entero**. Un
# diálogo que se pasa de alto deja los botones de abajo fuera de alcance y no
# hay lint que lo note.
class SonidosModalTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))
    abrir_etiquetar
    click_on "Sonidos"
    assert_selector "#sonido-config-title", wait: 5
  end

  test "estan todas las opciones de error, y la de por defecto viene marcada" do
    SonidosDeError::VARIANTES.each do |variante|
      assert_text variante[:nombre]
      assert_selector "input[name='sonido_error_variante'][value='#{variante[:id]}']"
    end

    # El digitador de los fixtures no eligió ninguna: tiene la de la columna,
    # que desde PR-C29.9 es la alarma.
    assert_selector "input[name='sonido_error_variante'][value='#{SonidosDeError::DEFAULT}']:checked"
  end

  test "estan los sonidos que el sistema toca de verdad" do
    SonidosDeEscaneo::BOTONES.each do |boton|
      assert_selector "[data-tono='#{boton[:accion]}']",
                      text: "Escuchar"
      assert_text boton[:etiqueta]
    end
  end

  test "el sonido de pre-alerta se puede probar" do
    # Es EL que estaba faltando: el que suma la voz arriba del pito.
    assert_selector "[data-tono='speakPreAlerta']"
  end

  test "el modal entra en la pantalla" do
    dialogo = find("dialog[open]")
    alto_dialogo = dialogo.evaluate_script("this.getBoundingClientRect().height")
    alto_ventana = page.evaluate_script("window.innerHeight")

    assert_operator alto_dialogo, :<=, alto_ventana,
                    "el diálogo se pasa de alto: los botones de abajo quedan fuera de alcance"
  end

  test "elegir una variante la guarda" do
    find("input[name='sonido_error_variante'][value='triple']").click

    # El `fetch` va con 400 ms de debounce para no pegarle al server en cada
    # click del slider, así que la preferencia no está guardada al volver del
    # click.
    esperar { users(:digitador).reload.sonido_error_variante == "triple" }

    assert_equal "triple", users(:digitador).reload.sonido_error_variante
  end

  # C29-08 · *"Cada error tiene que tener un tono distinto para que ellos
  # sepan."* El tipo distinto y la sucursal distinta eligen su opción acá.
  test "cada error con sonido propio elige su opción, y queda guardada" do
    SonidosDeError::MOTIVOS.each do |m|
      assert_selector "select[data-motivo='#{m[:id]}']"
      assert_selector "[data-tono='#{m[:accion]}']", text: "Escuchar"
    end

    find("select[data-motivo='sucursal_distinta']").find("option[value='descendente']").select_option

    esperar { users(:digitador).reload.sonido_error_sucursal == "descendente" }
    assert_equal "descendente", users(:digitador).reload.sonido_error_sucursal
  end

  private

  def esperar(segundos: 5)
    limite = Process.clock_gettime(Process::CLOCK_MONOTONIC) + segundos
    sleep 0.1 until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) > limite
  end


  def abrir_etiquetar
    abrir_sesion_etiquetar(TipoEnvio.activos.order(:nombre).first)
  end
end
