require "application_system_test_case"

# C22-01 · Yusef, 2026-08-31, probando la pantalla en vivo:
#
#   "La sección de etiquetar, en la parte **cuando vamos a actualizar un
#    paquete, el limpiar no está limpiando**."
#   "Le doy a actualizar y digo no, no me equivoqué, era eso. **F2 se queda. Ya
#    te queda actualizando.** Y se queda esto, **tiene que limpiar todo**."
#
# Con la excepción que fijó ahí mismo:
#
#   **Jorge:** "¿A excepción de la sesión, verdad?" · **Yusef:** "Sí, excepción
#   correcto."
#
# El bug: en modo actualización el formulario lo renderiza el servidor apuntando
# a `PATCH /etiquetar/:id`, y `clearForm` limpiaba los campos sin tocar la acción
# del form. Quedaba en blanco a la vista y apuntando al paquete anterior por
# dentro — el siguiente escaneo se guardaba encima de él.
#
# Va como system test porque es lo único que ve una tecla y la acción real de un
# formulario. Un test de integración arma los params a mano y nunca miraría el
# `action`.
class EtiquetarLimpiarSaleDeActualizarTest < ApplicationSystemTestCase
  setup do
    ingresar(users(:digitador))
    @existente = crear_recibido
    abrir_sesion_etiquetar(TipoEnvio.find(@existente.tipo_envio_id))
  end

  test "F2 en modo actualización sale del modo, y la sesión se queda" do
    visit etiquetar_path(paquete_id: @existente.id)
    assert_text "Actualizando", wait: 5
    assert_match %r{/etiquetar/#{@existente.id}}, accion_del_form

    find("body").send_keys(:f2)

    # El banner es el síntoma que se ve; la acción del form es el que cobra.
    assert_no_text "Actualizando", wait: 5
    assert_no_match %r{/etiquetar/#{@existente.id}}, accion_del_form
    assert_equal "", find("#paquete_tracking", visible: :all).value

    # La excepción de Yusef: la sesión de tipo de envío sigue abierta. Vive en
    # el servidor, así que recargar no la toca — solo «Finalizar sesión».
    assert_button BOTON_FINALIZAR_SESION, wait: 5
    assert_no_text "¿Qué tipo de envío vas a trabajar?"
  end

  # El otro lado de la misma moneda, y la razón por la que el arreglo no es
  # "recargar siempre": en alta, F2 es el atajo del escaneo rápido y una vuelta
  # al servidor por cada limpieza sería peor que el bug.
  #
  # Se afirma con un centinela: una recarga se lleva puesto el `window`, la
  # limpieza en el lugar no.
  test "F2 en modo alta no recarga la pantalla" do
    find("#paquete_tracking").send_keys("1Z999LIMPIA001")
    page.execute_script("window.__sinRecargar = true")

    find("body").send_keys(:f2)

    assert_equal "", find("#paquete_tracking").value
    assert page.evaluate_script("window.__sinRecargar === true"),
           "F2 recargó la pantalla en modo alta: eso frena el escaneo de Miami"
  end

  private

  # El `action` que el navegador tiene puesto AHORA, no el que se renderizó.
  def accion_del_form
    page.evaluate_script("document.querySelector('form[data-etiquetar-target=form]').action")
  end

  def crear_recibido
    Paquete.create!(
      tracking: "1Z999ACTUALIZA#{SecureRandom.hex(3).upcase}", cliente: clientes(:juan),
      tipo_envio: tipo_envios(:cer), sucursal_recepcion: sucursales(:miami),
      estado: "recibido_miami", descripcion: "Perfumes", user: users(:digitador)
    )
  end
end
