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

    ingresar(@user)
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
    # Cualquiera sirve: al actualizar, el tipo de envío del paquete nunca se
    # pisa con el de la sesión. El helper además espera a que la sesión quede
    # abierta antes de que el `visit` de abajo corra contra el chooser.
    abrir_sesion_etiquetar(TipoEnvio.activos.order(:nombre).first)
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
end
