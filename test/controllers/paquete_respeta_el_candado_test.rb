require "test_helper"

# C30-06 · El candado del manifiesto finalizado, también desde /paquetes.
#
# QA lo encontró en PR-C30.7: el formulario del paquete permite `manifiesto_id`
# —la reasignación desde el form es un pedido viejo— y nada preguntaba por el
# candado. Con un PATCH armado a mano:
#
#   · `manifiesto_id=<finalizado>` metía un paquete en `recibido_miami` en un
#     manifiesto que ya había viajado;
#   · `manifiesto_id=""` sobre uno de adentro lo dejaba en `enviado_honduras`
#     sin manifiesto.
#
# Es lo de Yusef: *"ya nos pasó que venían y sin querer tocaban el manifiesto
# que ya se había ido"*. La reasignación desde el form se queda, pero pasa por
# las mismas puertas que la ficha del manifiesto (`sacar!` del viejo, `meter!`
# al nuevo) y se rechaza con el mismo motivo si el viejo **o** el nuevo no se
# pueden tocar.
class PaqueteRespetaElCandadoTest < ActionDispatch::IntegrationTest
  setup do
    @supervisor = users(:supervisor_miami)
    @cer = tipo_envios(:cer)

    @finalizado = manifiestos(:creado)
    @adentro = paquetes(:empacado)
    @adentro.update_columns(tipo_envio_id: @cer.id)
    @finalizado.meter!(@adentro, user: @supervisor)
    assert_not FinalizarManifiesto.new(@finalizado, user: @supervisor).call.bloqueado?
    @finalizado.reload
    assert @finalizado.enviado?

    @abierto = Manifiesto.create!(tipo_envios: [ @cer ], sucursal_origen: sucursales(:miami), user: @supervisor)

    @suelto = paquetes(:recibido)
    @suelto.tareas.update_all(estado: "realizada")
    @suelto.update_columns(tipo_envio_id: @cer.id, manifiesto_id: nil)

    post session_url, params: { email_address: @supervisor.email_address, password: "password123" }
  end

  def reasignar(paquete, manifiesto_id)
    patch paquete_url(paquete), params: { paquete: { manifiesto_id: manifiesto_id } }
  end

  # ── Lo que QA reprodujo ─────────────────────────────────────────────────

  test "no mete un paquete en un manifiesto finalizado" do
    reasignar(@suelto, @finalizado.id)

    assert_response :forbidden
    assert_match "finalizado y bloqueado", response.body
    assert_nil @suelto.reload.manifiesto_id
    assert_equal "recibido_miami", @suelto.estado
  end

  test "no saca un paquete de un manifiesto finalizado" do
    reasignar(@adentro, "")

    assert_response :forbidden
    assert_equal @finalizado.id, @adentro.reload.manifiesto_id
    assert_equal "enviado_honduras", @adentro.estado
  end

  test "no lo pasa de un finalizado a uno abierto" do
    reasignar(@adentro, @abierto.id)

    assert_response :forbidden
    assert_equal @finalizado.id, @adentro.reload.manifiesto_id
  end

  # ── La reasignación de siempre sigue andando, por las mismas puertas ────

  test "entre dos abiertos se mueve, suelta la caja y las fechas son las del nuevo" do
    otro = Manifiesto.create!(tipo_envios: [ @cer ], sucursal_origen: sucursales(:miami), user: @supervisor)
    caja = otro.cajas.create!(peso: 5, user: @supervisor)
    otro.meter!(@suelto, user: @supervisor, caja_manifiesto: caja)

    reasignar(@suelto, @abierto.id)

    assert_redirected_to paquete_url(@suelto)
    @suelto.reload
    assert_equal @abierto.id, @suelto.manifiesto_id
    assert_nil @suelto.caja_manifiesto_id, "en el manifiesto nuevo no está en ninguna caja"
    assert_nil @suelto.fecha_enviado, "el nuevo no salió: no tiene fecha de enviado"
    assert_equal 1, @abierto.reload.cantidad_paquetes, "el nuevo recalcula sus totales"
    assert_equal 0, otro.reload.cantidad_paquetes, "y el viejo los suyos"
  end

  test "con la edición abierta, el supervisor lo saca y vuelve como si no hubiera viajado" do
    @finalizado.abrir_edicion!(@supervisor)

    reasignar(@adentro, "")

    assert_redirected_to paquete_url(@adentro)
    @adentro.reload
    assert_nil @adentro.manifiesto_id
    assert_equal "recibido_miami", @adentro.estado
    assert_nil @adentro.fecha_enviado
  end

  test "con la edición abierta, el que entra sale como los demás, con sus fechas" do
    @finalizado.abrir_edicion!(@supervisor)

    reasignar(@suelto, @finalizado.id)

    assert_redirected_to paquete_url(@suelto)
    @suelto.reload
    assert_equal @finalizado.id, @suelto.manifiesto_id
    assert_equal "enviado_honduras", @suelto.estado
    # La estampa `meter!` al pasarlo a enviado, como a los que salieron al
    # finalizar: segundos después de la del manifiesto, no la copia exacta.
    assert_in_delta @finalizado.fecha_enviado.to_f, @suelto.fecha_enviado.to_f, 60
  end

  # Todo o nada: si el nuevo no lo deja entrar, tampoco sale del viejo ni se
  # guarda lo demás del formulario.
  test "si el nuevo lo rechaza, no queda nada a medias" do
    @finalizado.abrir_edicion!(@supervisor)
    otro = Manifiesto.create!(tipo_envios: [ @cer ], sucursal_origen: sucursales(:miami), user: @supervisor)
    otro.meter!(@suelto, user: @supervisor)
    Tarea.create!(titulo: "Revisar", estado: "pendiente", departamento: "miami", origen: "manual",
                  paquete: @suelto, cliente: @suelto.cliente, asignado_a: @supervisor, bloquea_avance: true)

    patch paquete_url(@suelto), params: { paquete: { manifiesto_id: @finalizado.id, descripcion: "Cambiada" } }

    assert_response :unprocessable_entity
    @suelto.reload
    assert_equal otro.id, @suelto.manifiesto_id, "no salió del viejo"
    assert_not_equal "Cambiada", @suelto.descripcion, "y lo demás del formulario tampoco se guardó"
  end

  # PR-C30.14 · Uno recibido se reabre, pero el que ya tiene medición en San
  # Pedro no sale (`Manifiesto::NoSeSaca`), tampoco por el formulario del
  # paquete: se dice por qué y no se guarda nada.
  test "de uno recibido y reabierto no saca al que ya se midió, y lo dice" do
    @finalizado.update_columns(estado: "recibido")
    @finalizado.abrir_edicion!(@supervisor)
    @adentro.update_columns(estado: "en_aduana", medicion_sesion: "tanda-1")

    patch paquete_url(@adentro), params: { paquete: { manifiesto_id: "", descripcion: "Cambiada" } }

    assert_response :unprocessable_entity
    assert_match "ya se midió", response.body
    @adentro.reload
    assert_equal @finalizado.id, @adentro.manifiesto_id
    assert_not_equal "Cambiada", @adentro.descripcion
  end

  test "un manifiesto que no existe no deja al paquete sin manifiesto" do
    @abierto.meter!(@suelto, user: @supervisor)

    reasignar(@suelto, 0)

    assert_response :unprocessable_entity
    assert_equal @abierto.id, @suelto.reload.manifiesto_id
  end

  # ── Las otras puertas que mueven el manifiesto de un paquete ────────────

  # El retroceso de estado (`apply_retroceso_cleanup!`) suelta el manifiesto
  # al volver antes de `enviado_honduras`.
  test "un retroceso de estado no lo saca de un manifiesto finalizado" do
    patch paquete_url(@adentro), params: { paquete: { estado: "recibido_miami" }, confirm_retroceso: "1" }

    assert_response :forbidden
    assert_equal @finalizado.id, @adentro.reload.manifiesto_id
    assert_equal "enviado_honduras", @adentro.estado
  end

  # El retroceso que suelta el manifiesto, con el manifiesto **abierto**: sale
  # por la misma puerta que `sacar!` (`Manifiesto#soltar!`). Antes ponía
  # `manifiesto_id` en nil y nada más: la caja seguía apuntándolo y el
  # manifiesto lo seguía contando.
  test "un retroceso en un manifiesto abierto suelta la caja y recalcula" do
    caja = @abierto.cajas.create!(peso: 5, user: @supervisor)
    @abierto.meter!(@suelto, user: @supervisor, caja_manifiesto: caja, estado: "empacado")
    assert_equal 1, @abierto.reload.cantidad_paquetes

    patch paquete_url(@suelto), params: { paquete: { estado: "recibido_miami" }, confirm_retroceso: "1" }

    assert_redirected_to paquete_url(@suelto)
    @suelto.reload
    assert_nil @suelto.manifiesto_id
    assert_nil @suelto.caja_manifiesto_id, "la caja lo soltó"
    assert_equal "recibido_miami", @suelto.estado
    assert_equal 0, @abierto.reload.cantidad_paquetes, "el manifiesto lo dejó de contar"
    assert_empty caja.reload.paquetes
  end

  # Y el estado es **el que eligió el supervisor**, no el de antes de salir:
  # `sacar!` lo devolvería a `recibido_miami`, el retroceso pidió `empacado`.
  test "con la edición abierta, el retroceso respeta el estado elegido" do
    @finalizado.abrir_edicion!(@supervisor)

    patch paquete_url(@adentro), params: { paquete: { estado: "empacado" }, confirm_retroceso: "1" }

    assert_redirected_to paquete_url(@adentro)
    @adentro.reload
    assert_nil @adentro.manifiesto_id
    assert_nil @adentro.caja_manifiesto_id
    assert_equal "empacado", @adentro.estado, "no lo pisó con el estado de antes de salir"
    assert_nil @adentro.fecha_enviado
    assert_equal 0, @finalizado.reload.cantidad_paquetes
  end

  # Partir en cajas crea hermanas que heredan el manifiesto; bajarlas las
  # borra. Las dos cosas cambian la carga de uno que ya viajó.
  test "no se parte en cajas un paquete de un manifiesto finalizado" do
    antes = @finalizado.paquetes.count

    patch paquete_url(@adentro), params: { paquete: { cantidad_paquetes: 3 } }

    assert_response :unprocessable_entity
    assert_match "finalizado y bloqueado", response.body
    assert_equal antes, @finalizado.paquetes.count
  end
end
