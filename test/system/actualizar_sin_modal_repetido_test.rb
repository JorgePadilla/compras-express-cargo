require "application_system_test_case"

# Jorge, 2026-08-19: *"cuando estamos actualizando hay un comportamiento raro:
# cierro el modal y doy click en la forma y se vuelve a abrir el modal"*.
#
# Al entrar por `?paquete_id=` el tracking viene puesto, y el primer blur del
# campo salía a preguntar si existía. Claro que existía — **era él**.
#
# Va como system test porque el aviso lo dispara el `blur` del campo: ningún
# test de integración puede ver un modal abrirse.
class ActualizarSinModalRepetidoTest < ApplicationSystemTestCase
  setup do
    visit new_session_path
    fill_in "email_address", with: users(:digitador).email_address
    fill_in "password", with: "password123"
    click_on "Iniciar Sesion"
    assert_no_current_path new_session_path, wait: 8

    visit etiquetar_path
    if page.has_text?("¿Qué tipo de envío vas a trabajar?", wait: 3)
      first("button[name='tipo_envio_id']").click
    end
    assert_selector "#paquete_tracking", wait: 8

    @paquete = Paquete.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                               tracking: "1ZSINMODALREPE01", descripcion: "x",
                               estado: "recibido_miami", user: users(:digitador),
                               sucursal_recepcion: sucursales(:miami))
  end

  test "actualizando un paquete, su propio tracking no dispara el aviso" do
    visit etiquetar_path(paquete_id: @paquete.id)
    assert_selector "#paquete_tracking", wait: 5

    # Lo que hacía Jorge: tocar el campo y seguir llenando el formulario.
    find("#paquete_tracking").click
    find("#paquete_descripcion").click

    # `assert_no_selector` devuelve apenas ve que no está, así que a secas pasa
    # **antes** de que la consulta vuelva — daba verde con el bug puesto, y la
    # mutación lo destapó. Hay que darle tiempo a que el modal aparezca para
    # poder afirmar que no aparece.
    sleep 2
    assert_no_selector "[data-etiquetar-target='duplicateModal']:not(.hidden)"
  end

  test "actualizando una caja de un split, sus hermanas tampoco lo disparan" do
    # Jorge, 2026-08-21: *"cuando estoy actualizando un tracking y le voy a dar
    # click a un campo, el modal lo sigue tirando"*.
    #
    # El arreglo de `PR-C7.29` excluía **la fila** y quedó corto: las cajas de un
    # split comparten tracking, así que al actualizar la Caja 1 el sistema
    # encontraba la Caja 2. Con un paquete suelto no pasaba — y por eso el test de
    # entonces, que usaba uno suelto, lo dio por bueno.
    cajas = Paquete.crear_split!(
      attrs: { cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
               tracking: "1ZSPLITSINMODAL1", descripcion: "Dos cajas",
               estado: "recibido_miami", user: users(:digitador),
               sucursal_recepcion: sucursales(:miami) },
      total_cajas: 2, por_caja: {})

    visit etiquetar_path(paquete_id: cajas.first.id)
    assert_selector "#paquete_tracking", wait: 5

    find("#paquete_tracking").click
    find("#paquete_descripcion").click

    # Con tiempo para que vuelva la consulta: `assert_no_selector` a secas
    # devuelve antes de eso y pasaría con el bug puesto.
    sleep 2
    assert_no_selector "[data-etiquetar-target='duplicateModal']:not(.hidden)"
  end

  test "el de otro paquete si lo dispara, que es para lo que existe" do
    # Excluirse a sí mismo no puede volverse ciego a los duplicados de verdad.
    otro = Paquete.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                           tracking: "1ZOTROQUESIAVISA", descripcion: "y",
                           estado: "recibido_miami", user: users(:digitador),
                           sucursal_recepcion: sucursales(:miami))

    visit etiquetar_path(paquete_id: @paquete.id)
    assert_selector "#paquete_tracking", wait: 5

    find("#paquete_tracking").set(otro.tracking)
    find("#paquete_descripcion").click

    assert_selector "[data-etiquetar-target='duplicateModal']:not(.hidden)", wait: 5
  end
end
