require "application_system_test_case"

# C20-04, la mitad de la pantalla: que contestar «1» en el modal de etiquetas
# de verdad baje el envío a una caja.
#
# El servidor sabía hacerlo desde `PR-C7.23`; lo que faltaba era que la
# pantalla se lo dijera. El JS mandaba la cantidad **solo si era mayor que 1**,
# así que confirmar «1» no mandaba nada: el servidor no recibía cantidad, no
# ajustaba el split, y el paquete seguía en tres cajas mientras la pantalla
# decía "actualizado" y salían tres etiquetas.
#
# Va como system test porque el bug vivía justo en el puente entre el modal y
# el request: los tests de servidor mandan `etiquetas` a mano y pasan igual.
class EtiquetarBajarAUnaCajaTest < ApplicationSystemTestCase
  setup do
    @user = users(:digitador)
    @cer = tipo_envios(:cer)
    @miami = sucursales(:miami)
    @cajas = crear_split(3)

    visit new_session_path
    fill_in "email_address", with: @user.email_address, wait: 10
    fill_in "password", with: "password123"
    click_on "Iniciar Sesion"
    assert_no_current_path new_session_path, wait: 8
  end

  test "contestar 1 en el modal baja el envío a una sola caja" do
    abrir_en_modo_actualizacion(@cajas.first)

    find("[data-action*='etiquetar#submitFormWithPrint']", match: :first).click

    # El modal arranca en la cantidad que el envío tiene hoy (PR-C7.23), para
    # que un Enter distraído no baje un split de tres a uno.
    campo = find("[data-etiquetar-target='etiquetasInput']")
    assert_equal "3", campo.value

    campo.fill_in with: "1"
    find("[data-action*='etiquetar#confirmarEtiquetas']").click

    esperar { Paquete.where(tracking: @cajas.first.tracking).count == 1 }
    quedan = Paquete.where(tracking: @cajas.first.tracking)
    assert_equal 1, quedan.size, "confirmar «1» se seguía descartando en silencio"
    assert_equal 1, quedan.first.cantidad_paquetes
  ensure
    cerrar_pestanas_extra
  end

  private

  def abrir_en_modo_actualizacion(paquete)
    visit etiquetar_path
    if page.has_text?("¿Qué tipo de envío vas a trabajar?", wait: 3)
      # Cualquiera sirve: al actualizar, el tipo de envío del paquete nunca se
      # pisa con el de la sesión.
      first("form[action='#{iniciar_sesion_etiquetar_path}'] button").click
      # Esperar a que la sesión quede abierta antes de volver a navegar: si no,
      # el `visit` de abajo corre contra el chooser todavía en pantalla.
      assert_selector "#paquete_tracking", wait: 5
    end
    visit etiquetar_path(paquete_id: paquete.id)
    assert_selector "#paquete_tracking", wait: 5
  end

  def crear_split(n)
    primero = Paquete.create!(
      tracking: "SYS#{SecureRandom.hex(4)}", cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
      sucursal_recepcion: sucursales(:miami), estado: "recibido_miami",
      descripcion: "Perfumes", peso: 5, user: users(:digitador)
    )
    primero.update_columns(numero_caja: 1, cantidad_paquetes: n)
    resto = (2..n).map do |i|
      Paquete.create!(
        tracking: primero.tracking, cliente: primero.cliente, tipo_envio: primero.tipo_envio,
        sucursal_recepcion: primero.sucursal_recepcion, numero_recepcion: primero.numero_recepcion,
        estado: "recibido_miami", descripcion: "Perfumes", peso: 5,
        numero_caja: i, cantidad_paquetes: n, user: users(:digitador)
      )
    end
    [ primero, *resto ]
  end

  def esperar(segundos: 10)
    limite = Process.clock_gettime(Process::CLOCK_MONOTONIC) + segundos
    sleep 0.15 until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) > limite
  end

  # El window.open de la impresión nace después del guardado y puede quedar
  # huérfano para el test siguiente del worker.
  def cerrar_pestanas_extra
    b = page.driver.browser
    principal = b.window_handles.first
    b.window_handles[1..].to_a.each do |h|
      b.switch_to.window(h)
      b.close
    end
    b.switch_to.window(principal)
  end
end
