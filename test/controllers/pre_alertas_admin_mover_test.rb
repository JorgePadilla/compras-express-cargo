require "test_helper"

# PR-C6.48: mover un paquete a otra pre-alerta desde el editor de admin.
#
# El portal ya lo tenía. Admin solo podía hacerlo desde la ficha del paquete
# (`PaquetesController#mover_a_pre_alerta`), o sea: había que saber a qué
# paquete ir, salir del editor, y volver.
#
# **La regla de admin es más ancha que la del portal, a propósito.** El portal
# exige mismo cliente y mismo tipo de envío; acá se puede mover a la pre-alerta
# de cualquier cliente. Yusef, sobre el flujo equivalente del lado del paquete:
#
#   > "se permite mover a pre-alerta de cualquier cliente (caso típico:
#   >  **corregir asignación equivocada**)"
#
# Que es justamente el caso: si el paquete cayó en la pre-alerta del cliente
# equivocado, el destino correcto es de OTRO cliente. Con la regla del portal,
# el error no se podría arreglar.
class PreAlertasAdminMoverTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
    @origen = pre_alertas(:activa)
    @pap = @origen.pre_alerta_paquetes.create!(tracking: "1Z999MOVER1", descripcion: "Zapatos")
  end

  # ── El caso de Yusef ──

  test "mueve a la pre-alerta de OTRO cliente" do
    destino = pre_alerta_de(clientes(:maria))

    post mover_paquete_pre_alerta_url(@origen), params: {
      pre_alerta_paquete_id: @pap.id, destino_id: destino.id
    }

    assert_redirected_to edit_pre_alerta_url(@origen)
    assert_equal destino.id, @pap.reload.pre_alerta_id
  end

  test "mueve aunque el tipo de envio no coincida" do
    # El portal lo bloquea. Acá no: un tracking mal asignado puede haber caido
    # en un servicio que no era.
    destino = pre_alerta_de(clientes(:maria), tipo_envio: tipo_envios(:cem))
    @origen.update_columns(tipo_envio_id: tipo_envios(:cer).id)

    post mover_paquete_pre_alerta_url(@origen), params: {
      pre_alerta_paquete_id: @pap.id, destino_id: destino.id
    }

    assert_equal destino.id, @pap.reload.pre_alerta_id
  end

  test "los destinos incluyen los de otros clientes" do
    destino = pre_alerta_de(clientes(:maria))

    get destinos_disponibles_pre_alerta_url(@origen), params: { pre_alerta_paquete_id: @pap.id }

    ids = JSON.parse(response.body).map { |d| d["id"] }
    assert_includes ids, destino.id
  end

  test "el destino muestra de quien es" do
    # Con destinos de varios clientes, el numero de documento solo no alcanza
    # para saber si es el correcto.
    destino = pre_alerta_de(clientes(:maria))

    get destinos_disponibles_pre_alerta_url(@origen), params: { pre_alerta_paquete_id: @pap.id }

    fila = JSON.parse(response.body).find { |d| d["id"] == destino.id }
    assert_match(/#{clientes(:maria).codigo}/, fila["titulo"])
  end

  # ── Lo único que se sigue bloqueando ──

  test "no deja meterlo en una consolidacion ya cerrada" do
    # Ahí el cliente ya no puede reaccionar: es lo que el aviso de PR-C6.47
    # dice y esto lo hace cumplir del lado del servidor.
    destino = pre_alerta_de(clientes(:maria))
    destino.update_columns(consolidado: true, finalizado: true)

    post mover_paquete_pre_alerta_url(@origen), params: {
      pre_alerta_paquete_id: @pap.id, destino_id: destino.id
    }

    assert_equal @origen.id, @pap.reload.pre_alerta_id
    assert_match(/finaliz/, flash[:alert])
  end

  test "una consolidacion cerrada no aparece entre los destinos" do
    destino = pre_alerta_de(clientes(:maria))
    destino.update_columns(consolidado: true, finalizado: true)

    get destinos_disponibles_pre_alerta_url(@origen), params: { pre_alerta_paquete_id: @pap.id }

    assert_not_includes JSON.parse(response.body).map { |d| d["id"] }, destino.id
  end

  test "no deja moverlo a la misma pre-alerta" do
    post mover_paquete_pre_alerta_url(@origen), params: {
      pre_alerta_paquete_id: @pap.id, destino_id: @origen.id
    }

    assert_equal @origen.id, @pap.reload.pre_alerta_id
    assert_match(/no válido/i, flash[:alert])
  end

  test "no deja mover una fila de otra pre-alerta" do
    otra = pre_alerta_de(clientes(:maria))
    ajeno = otra.pre_alerta_paquetes.create!(tracking: "1Z999AJENO", descripcion: "x")
    destino = pre_alerta_de(clientes(:juan))

    post mover_paquete_pre_alerta_url(@origen), params: {
      pre_alerta_paquete_id: ajeno.id, destino_id: destino.id
    }

    assert_response :not_found
    assert_equal otra.id, ajeno.reload.pre_alerta_id, "movió una fila que no era de esta pre-alerta"
  end

  # ── Rastro ──

  test "queda escrito en el historial de las dos" do
    # Un paquete que aparece en otra pre-alerta sin explicacion es
    # indistinguible de un error de carga.
    destino = pre_alerta_de(clientes(:maria))

    post mover_paquete_pre_alerta_url(@origen), params: {
      pre_alerta_paquete_id: @pap.id, destino_id: destino.id
    }

    assert_match(/1Z999MOVER1/, @origen.reload.historial.to_s)
    assert_match(/1Z999MOVER1/, destino.reload.historial.to_s)
    assert_match(/#{users(:admin).nombre}/, destino.historial.to_s, "no dice quien lo movio")
  end

  test "no le manda mail al cliente" do
    # El portal si manda: ahi el movimiento lo hace el propio cliente sobre sus
    # pre-alertas. Este lo hace el equipo, y avisarle de una correccion interna
    # es una decision de negocio que nadie pidio.
    destino = pre_alerta_de(clientes(:maria))

    assert_no_enqueued_emails do
      post mover_paquete_pre_alerta_url(@origen), params: {
        pre_alerta_paquete_id: @pap.id, destino_id: destino.id
      }
    end
  end

  # ── La origen que queda vacía ──

  test "si era el ultimo, la origen se elimina" do
    @origen.pre_alerta_paquetes.where.not(id: @pap.id).destroy_all
    destino = pre_alerta_de(clientes(:maria))

    post mover_paquete_pre_alerta_url(@origen), params: {
      pre_alerta_paquete_id: @pap.id, destino_id: destino.id
    }

    assert_redirected_to pre_alertas_url
    assert @origen.reload.deleted_at.present?
  end

  # ── La pantalla ──

  test "el editor ofrece mover cada fila guardada" do
    get edit_pre_alerta_url(@origen)

    assert_select "#paquete_row_#{@pap.id} [data-action*='pre-alerta-mover#open']"
    assert_select "[data-pre-alerta-mover-target=modal]"
  end

  test "la fila nueva no ofrece mover" do
    # Una fila que todavia no existe no se puede mover a ningun lado.
    get edit_pre_alerta_url(@origen)

    plantilla = response.body[/<template[^>]*>.*?<\/template>/m].to_s
    assert_no_match(/pre-alerta-mover#open/, plantilla)
  end

  private

  def pre_alerta_de(cliente, tipo_envio: tipo_envios(:cer))
    PreAlerta.create!(cliente: cliente, tipo_envio: tipo_envio, titulo: "Destino",
                      estado: "pre_alerta", creado_por_tipo: "usuario",
                      creado_por_id: users(:admin).id)
  end
end
