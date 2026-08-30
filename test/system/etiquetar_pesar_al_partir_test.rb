require "application_system_test_case"

# C20-12 · «si ya tiene peso, obligarlo a llenar».
#
# Yusef, 2026-08-30, cuando Jorge le llevó `RP-51` —una caja de 5 lb partida
# en tres nacía como tres cajas de 5 lb—:
#
#   > "Si no tiene pesos, pues los ponemos sin pesos. Pero si ya tiene pesos,
#   >  tenemos que obligarlo a llenar, para evitar esta incoherencia."
#
# El modal de «¿cuántas etiquetas?» gana un segundo paso, solo cuando el envío
# ya tiene peso y se piden más cajas de las que hay. Va como system test
# porque las filas de peso las pinta el JS: ningún test de integración las ve.
# El servidor exige lo mismo por su cuenta (`etiquetar_pesar_al_partir_test`
# de controllers).
class EtiquetarPesarAlPartirTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))

    abrir_sesion_etiquetar(TipoEnvio.activos.order(:nombre).first)
    # El paquete tiene que ser del tipo de la sesión: si no, el aviso de «otro
    # tipo de envío» se pone adelante del modal.
    @tipo = TipoEnvio.find(find("[data-etiquetar-tipo-envio-sesion-value]", visible: :all)["data-etiquetar-tipo-envio-sesion-value"])
  end

  # Este archivo tenía acá su propia copia del cierre de pestañas, en un
  # `teardown`. Se fue: la clase base lo hace en `setup`, y en `setup` agarra
  # también la pestaña que nace tarde —el `window.open` sale del turbo-stream
  # del guardado—, que era justo la que se le escapaba al `teardown`.

  test "partir una caja con peso pide el peso de cada una, y no imprime sin todos" do
    paquete = crear_recibido(peso: 5)
    abrir_para_actualizar(paquete)

    pedir_etiquetas(3)

    # Segundo paso: tres pesos, todos vacíos — el de la caja sola era el del envío.
    assert_selector "[data-caja-peso]", count: 3, wait: 3
    assert_equal [ "", "", "" ], all("[data-caja-peso]").map(&:value)
    assert_text "La caja tenía 5 lb"
    assert_equal 1, Paquete.where(tracking: paquete.tracking).count, "imprimió sin pesar"

    # Enter sobre uno vacío no avanza ni imprime; Imprimir con uno vacío tampoco.
    find("[data-caja-peso='1']").set("2")
    find("[data-caja-peso='2']").set("2")
    find("[data-caja-peso='3']").send_keys(:enter)
    click_on "Imprimir"
    assert_selector "[data-etiquetar-target='etiquetasModal'][open]"
    assert_equal 1, Paquete.where(tracking: paquete.tracking).count, "imprimió con un peso vacío"

    # Con los tres, Enter en el último confirma.
    find("[data-caja-peso='3']").set("1.5").send_keys(:enter)

    assert_no_selector "[data-etiquetar-target='etiquetasModal'][open]", wait: 5
    esperar { Paquete.where(tracking: paquete.tracking).count == 3 }
    assert_equal [ 2.0, 2.0, 1.5 ],
                 Paquete.where(tracking: paquete.tracking).order(:numero_caja).map { |c| c.peso.to_f },
                 "el 5 de la caja original tenía que irse: después de reempacar ya no vale"
  end

  test "sin peso no pregunta nada y las cajas nacen sin peso" do
    paquete = crear_recibido(peso: nil)
    abrir_para_actualizar(paquete)

    pedir_etiquetas(3)

    assert_no_selector "[data-caja-peso]"
    esperar { Paquete.where(tracking: paquete.tracking).count == 3 }
    assert_equal [ nil, nil, nil ], Paquete.where(tracking: paquete.tracking).order(:numero_caja).map(&:peso)
  end

  test "un split ya pesado trae los pesos que tiene y pide solo los nuevos" do
    cajas = crear_split(2, pesos: [ 3, 4 ])
    abrir_para_actualizar(cajas.first)

    pedir_etiquetas(4)

    assert_selector "[data-caja-peso]", count: 4, wait: 3
    assert_equal [ "3", "4", "", "" ], all("[data-caja-peso]").map(&:value)
    assert_text "pesá las cajas nuevas"
  end

  private

  def abrir_para_actualizar(paquete)
    visit etiquetar_path(paquete_id: paquete.id)
    assert_text "Actualizando", wait: 5
  end

  def pedir_etiquetas(cantidad)
    first("button", text: "Guardar + Imprimir").click
    assert_selector "[data-etiquetar-target='etiquetasModal'][open]", wait: 3
    find("[data-etiquetar-target='etiquetasInput']").set(cantidad.to_s)
    click_on "Imprimir"
  end

  def crear_recibido(peso:)
    Paquete.create!(
      tracking: "PESAR#{SecureRandom.hex(4)}", cliente: clientes(:juan), tipo_envio: @tipo,
      sucursal_recepcion: sucursales(:miami), estado: "recibido_miami", descripcion: "Perfumes",
      peso: peso, user: users(:digitador)
    )
  end

  def crear_split(n, pesos:)
    primero = crear_recibido(peso: pesos[0])
    primero.update_columns(numero_caja: 1, cantidad_paquetes: n)
    resto = (2..n).map do |i|
      Paquete.create!(
        tracking: primero.tracking, cliente: primero.cliente, tipo_envio: @tipo,
        sucursal_recepcion: sucursales(:miami), numero_recepcion: primero.numero_recepcion,
        estado: "recibido_miami", descripcion: "Perfumes", peso: pesos[i - 1],
        numero_caja: i, cantidad_paquetes: n, user: users(:digitador)
      )
    end
    [ primero, *resto ]
  end

  def esperar(segundos: 8)
    limite = Process.clock_gettime(Process::CLOCK_MONOTONIC) + segundos
    sleep 0.1 until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) > limite
  end
end
