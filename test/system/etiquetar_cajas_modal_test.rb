require "application_system_test_case"

# Cuántas cajas trae un tracking, y quién lo dice.
#
# Esto ya cambió tres veces, y las tres por lo mismo — que haya **una sola
# fuente** para el número:
#
#   · `PR-C6.17`: un modal en F9 preguntaba "¿cuántas cajas?".
#   · `PR-C6.18b`: Jorge lo probó y lo mandó a quitar — *"el F9 era como
#     confuso"*. La cantidad pasó a un campo del formulario, junto al peso.
#   · `A7-20`: el campo también se fue. Las cajas se agregan **una por una** con
#     F6, y la cantidad sale de contar las filas: si hay una sola fuente, no hay
#     dos números que puedan discrepar.
#
# Y ahora vuelve a preguntar, pero **solo cuando no se midió nada**. Yusef,
# 2026-08-18: *"en etiquetar casi nunca medimos y pesamos… cuando la cantidad de
# cajas guardadas sea cero, que pregunte cuántas son"*. La condición es lo que lo
# distingue del modal viejo: si hay aunque sea una caja cargada, ella manda y el
# modal ni aparece.
#
# Va como system test porque las filas y el modal los pinta el JS: ningún test
# de integración puede verlos.
class EtiquetarCajasModalTest < ApplicationSystemTestCase
  setup do
    visit new_session_path
    fill_in "email_address", with: users(:digitador).email_address
    fill_in "password", with: "password123"
    click_on "Iniciar Sesion"
    assert_no_current_path new_session_path, wait: 5

    visit etiquetar_path
    if page.has_text?("¿Qué tipo de envío vas a trabajar?", wait: 3)
      first("form[action='#{iniciar_sesion_etiquetar_path}'] button").click
    end
    assert_selector "#paquete_tracking", wait: 5
  end

  # Guardar con impresión abre la etiqueta en otra pestaña. Si se quedan
  # abiertas, el test siguiente arranca en la pestaña equivocada — y el síntoma
  # no dice eso: `EtiquetaCierraVentanaTest` empezó a fallar con "no encuentro
  # el campo email_address", que parece un problema de login.
  teardown do
    b = page.driver.browser
    principal = b.window_handles.first
    b.window_handles[1..].to_a.each do |h|
      b.switch_to.window(h)
      b.close
    end
    b.switch_to.window(principal)
  rescue StandardError
    # Si el navegador ya se cerró, no hay nada que limpiar.
  end

  test "ya no hay un campo de cantidad de cajas" do
    # `A7-20`. Mientras exista, hay dos fuentes para el mismo número.
    assert_no_selector "#paquete_cantidad_paquetes", visible: :all
  end

  test "las cajas se agregan una por una" do
    agregar_caja(peso: 12.5)
    assert_selector ".caja-fila", count: 1, wait: 3

    agregar_caja(peso: 30)
    assert_selector ".caja-fila", count: 2
  end

  test "cada caja se lleva su propio peso" do
    agregar_caja(peso: 12.5)
    agregar_caja(peso: 30)

    pesos = page.all("input[name^='paquete[cajas]'][name$='[peso]']", visible: :all).map { |i| i.value.to_f }
    assert_equal [ 12.5, 30.0 ], pesos.sort
  end

  test "sin medir nada, Guardar + Imprimir pregunta cuantas etiquetas" do
    assert_selector ".caja-fila", count: 0
    llenar_lo_minimo

    # Hay dos: la barra de arriba y la de abajo. Cualquiera sirve.
    first("button", text: "Guardar + Imprimir").click

    assert_selector "[data-etiquetar-target='etiquetasModal'][open]", wait: 3
    assert_text "¿Cuántas etiquetas se imprimen?"
  end

  test "lo que se contesta en el modal es lo que se graba" do
    # La única prueba de que el JS manda la cantidad y el servidor la lee: los
    # tests de integración postean `etiquetas` a mano, así que no ven el cable.
    tracking = "1Z999MODALGRABA1"
    find("#paquete_tracking").set(tracking)
    find("[data-etiquetar-target='clienteInput']").set("Juan")
    find("[data-etiquetar-target='clienteDropdown'] *", match: :first, wait: 5).click

    first("button", text: "Guardar + Imprimir").click
    assert_selector "[data-etiquetar-target='etiquetasModal'][open]", wait: 3
    find("[data-etiquetar-target='etiquetasInput']").set("3")
    click_on "Imprimir"

    # El split avisa con su propio texto, no con el de un paquete solo.
    assert_text "Tracking dividido en 3 cajas", wait: 10
    assert_equal 3, Paquete.where(tracking: tracking).count
    assert_equal [ 1, 2, 3 ], Paquete.where(tracking: tracking).order(:numero_caja).map(&:numero_caja)
  end

  test "la cantidad no se le pega al paquete siguiente" do
    # El bug de `PR-C6.31`, otra vez y por otra puerta: el campo oculto de la
    # cantidad vive en el formulario, y `clearForm` no toca los ocultos. Si no
    # se borra al mandar el siguiente, el paquete de después nace con la
    # cantidad del anterior — en silencio, que es lo peor.
    guardar_con_etiquetas("1Z999PEGADA0001", 3)
    assert_text "Tracking dividido en 3 cajas", wait: 10

    guardar_con_etiquetas("1Z999PEGADA0002", 1)
    assert_text "guardado exitosamente", wait: 10

    assert_equal 1, Paquete.where(tracking: "1Z999PEGADA0002").count,
                 "el segundo paquete se llevó la cantidad del primero"
  end

  test "con una caja medida no pregunta nada" do
    # La condición que separa esto del modal que se quitó: la caja manda.
    llenar_lo_minimo
    agregar_caja(peso: 12.5)
    assert_selector ".caja-fila", count: 1, wait: 3

    first("button", text: "Guardar + Imprimir").click

    assert_no_selector "[data-etiquetar-target='etiquetasModal'][open]", wait: 2
  end

  test "actualizando, el modal arranca en las cajas que ya tiene" do
    # Con el 1 de siempre, abrir un envío de tres cajas y darle Enter las bajaba
    # a una — y `ajustar_split!` borra las sobrantes sin preguntar: el PIN de
    # supervisor solo cuida las que ya se cobraron. Yusef estaba subiendo de 3 a
    # 5; bajar estaba a un Enter de distancia.
    cajas = Paquete.crear_split!(
      attrs: { cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
               tracking: "1ZMODALDEFECTO01", descripcion: "Tres cajas",
               estado: "recibido_miami", user: users(:digitador),
               sucursal_recepcion: sucursales(:miami) },
      total_cajas: 3, por_caja: {})

    visit etiquetar_path(paquete_id: cajas.first.id)
    assert_selector "#paquete_tracking", wait: 5

    first("button", text: "Guardar + Imprimir").click
    assert_selector "[data-etiquetar-target='etiquetasModal'][open]", wait: 3

    assert_equal "3", find("[data-etiquetar-target='etiquetasInput']").value
  end

  test "Cant. Productos no divide nada" do
    # La confusión que originó todo esto: productos es el contenido, cajas son
    # los bultos físicos.
    find("#paquete_cantidad_productos").set("2")

    assert_selector ".caja-fila", count: 0
  end

  private

  def llenar_lo_minimo
    find("#paquete_tracking").set("1Z999MODALTEST#{rand(1000)}")
    find("[data-etiquetar-target='clienteInput']").set("Juan")
    find("[data-etiquetar-target='clienteDropdown'] *", match: :first, wait: 5).click
  end

  def guardar_con_etiquetas(tracking, cantidad)
    # Después de imprimir queda abierto el aviso de "guardar en la bolsa de…",
    # que tapa el formulario. El operario le da Listo; acá igual.
    click_on "Listo" if page.has_selector?("[data-etiquetar-target='sucursalModal'][open]", wait: 2)

    find("#paquete_tracking").set(tracking)
    find("[data-etiquetar-target='clienteInput']").set("Juan")
    find("[data-etiquetar-target='clienteDropdown'] *", match: :first, wait: 5).click

    first("button", text: "Guardar + Imprimir").click
    assert_selector "[data-etiquetar-target='etiquetasModal'][open]", wait: 3
    find("[data-etiquetar-target='etiquetasInput']").set(cantidad.to_s)
    click_on "Imprimir"
  end

  def agregar_caja(peso:)
    find("[data-caja-campo='peso']").set(peso)
    find("[data-cajas-repetidor-target='agregarBtn']").click
  end
end
