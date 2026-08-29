require "test_helper"

# C20-05: lo que se corrige al actualizar una caja es del ENVÍO, no de esa
# caja.
#
# Reproducido en vivo por Yusef sobre un envío de dos cajas a nombre de Diego:
#
#   > "Yo recibí dos paquetes a nombre de Diego. Después vine yo y lo
#   >  actualicé y lo cambié al nombre de Sofía."
#   > "Mira, aquí hay una cuestión: **quedó a nombre de Diego uno y el otro
#   >  quedó a nombre de Sofía**."
#
# Y lo mismo con la retención: *"mira que decía RET… solo uno te metió RET"*.
#
# `crear_split!` reparte estos datos entre las N cajas al dar de alta; el
# update nunca aprendió a hacerlo.
class EtiquetarPropagaAlEnvioTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @cer = tipo_envios(:cer)
    @cem = tipo_envios(:cem)
    @miami = sucursales(:miami)
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: @cer.id, sucursal_recepcion_id: @miami.id }
    @cajas = crear_split(2)
  end

  test "cambiar el cliente lo cambia en TODAS las cajas del envío" do
    otro = clientes(:maria)

    patch actualizar_etiquetar_url(@cajas.first), params: {
      paquete: { cliente_id: otro.id, descripcion: "Perfumes" }
    }

    assert_equal [ otro.id, otro.id ], @cajas.map { |c| c.reload.cliente_id },
                 "quedó a nombre de Diego uno y el otro a nombre de Sofía"
  end

  test "retener el envío lo retiene entero, con sus motivos" do
    motivo = MotivoRetencion.activos.ordered.first

    patch actualizar_etiquetar_url(@cajas.first), params: {
      paquete: { retener_miami: "1", motivo_retencion_ids: [ motivo.id ],
                 notas_retencion: "mercadería prohibida", descripcion: "Perfumes" }
    }

    @cajas.each do |caja|
      assert caja.reload.retener_miami?, "solo uno te metió RET"
      assert_equal [ motivo.id ], caja.motivo_retencion_ids
      assert_equal "mercadería prohibida", caja.notas_retencion
    end
  end

  test "quitar la retención la quita de todas" do
    @cajas.each { |c| c.update_columns(retener_miami: true) }

    patch actualizar_etiquetar_url(@cajas.first), params: {
      paquete: { retener_miami: "0", descripcion: "Perfumes" }
    }

    @cajas.each { |caja| assert_not caja.reload.retener_miami? }
  end

  test "el peso y las medidas NO se propagan: son de cada caja" do
    @cajas.last.update_columns(peso: 12)

    patch actualizar_etiquetar_url(@cajas.first), params: {
      paquete: { peso: 3, descripcion: "Perfumes" }
    }

    assert_equal 3, @cajas.first.reload.peso.to_i
    assert_equal 12, @cajas.last.reload.peso.to_i, "el peso es de la caja, no del envío"
  end

  # El caso que el acuñado del split habría roto si la propagación mirara
  # `saved_changes`: el número se persiste antes del save principal y se come
  # el cambio de tipo_envio.
  test "cambio de servicio Y cantidad en el mismo request: todas con el tipo nuevo" do
    patch actualizar_etiquetar_url(@cajas.first), params: {
      etiquetas: 3,
      paquete: { solicito_cambio_servicio: "1", tipo_envio_destino_id: @cem.id,
                 descripcion: "Perfumes" }
    }

    cajas = Paquete.where(tracking: @cajas.first.tracking).order(:numero_caja)
    assert_equal 3, cajas.size
    assert_equal [ @cem.id ] * 3, cajas.map(&:tipo_envio_id),
                 "un envío repartido en dos servicios no existe"
  end

  test "el cargo por cambio de servicio se cobra una vez, no una por caja" do
    patch actualizar_etiquetar_url(@cajas.first), params: {
      paquete: { solicito_cambio_servicio: "1", tipo_envio_destino_id: @cem.id,
                 descripcion: "Perfumes" }
    }

    marcadas = @cajas.count { |c| c.reload.solicito_cambio_servicio? }
    assert_equal 1, marcadas, "el cargo es del envío: una sola caja lo lleva"
    assert_equal [ @cem.id, @cem.id ], @cajas.map { |c| c.reload.tipo_envio_id }
  end

  private

  def crear_split(n)
    primero = Paquete.create!(
      tracking: "PRO#{SecureRandom.hex(4)}", cliente: clientes(:juan), tipo_envio: @cer,
      sucursal_recepcion: @miami, estado: "recibido_miami", descripcion: "Perfumes",
      peso: 5, user: @user
    )
    primero.update_columns(numero_caja: 1, cantidad_paquetes: n)
    resto = (2..n).map do |i|
      Paquete.create!(
        tracking: primero.tracking, cliente: primero.cliente, tipo_envio: @cer,
        sucursal_recepcion: @miami, numero_recepcion: primero.numero_recepcion,
        estado: "recibido_miami", descripcion: "Perfumes", peso: 5,
        numero_caja: i, cantidad_paquetes: n, user: @user
      )
    end
    [ primero, *resto ]
  end
end
