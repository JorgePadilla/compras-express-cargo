require "test_helper"

# Los tres bugs de actualizar que Yusef reprodujo en vivo el 2026-08-19.
class ActualizarLasCajasYElServicioTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: {
      email_address: users(:digitador).email_address, password: "password123"
    }
    abrir_sesion(tipo_envios(:cer))
  end

  # ── a. La cantidad de etiquetas se perdía ──────────────────────────────
  #
  #   > "Le digo que son dos etiquetas… solo te va a tirar una."
  #   > "Le di cinco y se quedó con las primeras tres."
  #
  # `update` leía `paquete_params[:cantidad_paquetes]` —un campo que `A7-20`
  # quitó del formulario— y nunca miraba el `etiquetas` del modal de `PR-C7.23`.

  test "pedir tres etiquetas al actualizar deja tres cajas" do
    paquete = crear_suelto("1ZACTCAJAS000001")

    patch actualizar_etiquetar_url(paquete),
          params: { etiquetas: "3", paquete: { descripcion: "tres cajas" } }

    assert_equal 3, Paquete.where(tracking: paquete.tracking).count
    assert_equal [ 1, 2, 3 ], Paquete.where(tracking: paquete.tracking).order(:numero_caja).map(&:numero_caja)
  end

  test "subir de tres a cinco crea las que faltan" do
    cajas = crear_split("1ZACTCAJAS000002", 3)

    patch actualizar_etiquetar_url(cajas.first),
          params: { etiquetas: "5", paquete: { descripcion: "cinco" } }

    assert_equal 5, Paquete.where(tracking: cajas.first.tracking).count
  end

  test "actualizar sin tocar la cantidad NO borra cajas" do
    # La trampa: `etiquetas_pedidas` contesta 1 cuando el parámetro falta —que es
    # lo correcto al dar de alta— y ese 1 acá significaría "bajalo a una caja".
    # Guardar un split de tres sin tocar nada le borraría dos.
    cajas = crear_split("1ZACTCAJAS000003", 3)

    patch actualizar_etiquetar_url(cajas.first), params: { paquete: { descripcion: "solo el texto" } }

    assert_equal 3, Paquete.where(tracking: cajas.first.tracking).count
  end

  test "el modal arranca en las cajas que ya tiene, no en 1" do
    # La otra mitad, la de la pantalla: con el 1 de siempre, abrir un envío de
    # tres cajas y darle Enter las bajaba a una.
    cajas = crear_split("1ZACTCAJAS000004", 3)

    get etiquetar_url(paquete_id: cajas.first.id)

    assert_match(/data-etiquetar-cajas-actuales-value="3"/, response.body)
  end

  test "dando de alta arranca en cero, o sea en 1" do
    get etiquetar_url

    assert_match(/data-etiquetar-cajas-actuales-value="0"/, response.body)
  end

  # ── b. El cambio de servicio solo tocaba una caja ──────────────────────
  #
  #   > "El tercero lo reconoce como exprés y los otros dos como CER… debería de
  #   >  cambiar todas."

  test "el cambio de servicio llega a todas las cajas del envio" do
    cajas = crear_split("1ZACTSERV0000001", 3)

    patch actualizar_etiquetar_url(cajas.first), params: { paquete: {
      solicito_cambio_servicio: "1", descripcion: "cambio",
      tipo_envio_destino_id: tipo_envios(:express).id
    } }

    tipos = Paquete.where(tracking: cajas.first.tracking).pluck(:tipo_envio_id).uniq
    assert_equal [ tipo_envios(:express).id ], tipos,
                 "un envío no puede ir repartido en dos servicios"
  end

  test "y queda registrado de dónde venían todas" do
    cajas = crear_split("1ZACTSERV0000002", 2)

    patch actualizar_etiquetar_url(cajas.first), params: { paquete: {
      solicito_cambio_servicio: "1", descripcion: "cambio",
      tipo_envio_destino_id: tipo_envios(:express).id
    } }

    anteriores = Paquete.where(tracking: cajas.first.tracking).pluck(:tipo_envio_anterior_id).uniq
    assert_equal [ tipo_envios(:cer).id ], anteriores
  end

  test "sin cambio de servicio, las hermanas no se tocan" do
    cajas = crear_split("1ZACTSERV0000003", 2)

    patch actualizar_etiquetar_url(cajas.first), params: { paquete: { descripcion: "solo texto" } }

    assert_equal [ tipo_envios(:cer).id ], Paquete.where(tracking: cajas.first.tracking).pluck(:tipo_envio_id).uniq
    assert_nil cajas.second.reload.tipo_envio_anterior_id
  end

  # ── c. Actualizar uno de otro tipo no avisaba ──────────────────────────
  #
  #   > "Es exprés y me está dejando actualizar en CER."

  test "actualizar un paquete de otro tipo de envio avisa" do
    otro = crear_suelto("1ZACTTIPO0000001", tipo: tipo_envios(:express))

    patch actualizar_etiquetar_url(otro), params: { paquete: { descripcion: "corregido" } }

    assert_match(/EXPRESS|Express/i, flash[:notice].to_s,
                 "no avisó que el paquete es de otro tipo de envío")
  end

  test "pero no bloquea: el dato se guarda igual" do
    # Corregirle el peso a un paquete de otro servicio no puede convertirlo al de
    # la sesión, y tampoco puede impedirse. Solo se avisa.
    otro = crear_suelto("1ZACTTIPO0000002", tipo: tipo_envios(:express))

    patch actualizar_etiquetar_url(otro), params: { paquete: { descripcion: "corregido" } }

    assert_equal "corregido", otro.reload.descripcion
    assert_equal tipo_envios(:express).id, otro.tipo_envio_id, "le pisaron el tipo con el de la sesión"
  end

  test "uno del mismo tipo no dice nada de más" do
    propio = crear_suelto("1ZACTTIPO0000003")

    patch actualizar_etiquetar_url(propio), params: { paquete: { descripcion: "corregido" } }

    # Sobre el texto real, no sobre una paráfrasis: el aviso dice "Ojo: es de X
    # y estás trabajando Y", así que buscar "otro tipo" pasaba igual con el
    # aviso puesto. La mutación lo destapó.
    assert_equal "Paquete #{propio.tracking} actualizado.", flash[:notice].to_s
  end

  private

  def abrir_sesion(tipo)
    post iniciar_sesion_etiquetar_url, params: {
      tipo_envio_id: tipo.id, sucursal_recepcion_id: sucursales(:miami).id
    }
  end

  def crear_suelto(tracking, tipo: tipo_envios(:cer))
    Paquete.create!(cliente: clientes(:juan), tipo_envio: tipo, tracking: tracking,
                    descripcion: "x", estado: "recibido_miami", user: users(:digitador),
                    sucursal_recepcion: sucursales(:miami))
  end

  def crear_split(tracking, total)
    Paquete.crear_split!(
      attrs: { cliente: clientes(:juan), tipo_envio: tipo_envios(:cer), tracking: tracking,
               descripcion: "Varias", estado: "recibido_miami", user: users(:digitador),
               sucursal_recepcion: sucursales(:miami) },
      total_cajas: total, por_caja: {}
    )
  end
end
