require "test_helper"

# PR-13.e: emitir una nota de débito o crédito pide el PIN de un supervisor.
#
# Por qué acá y no trabando cada línea como en la pre-factura: la nota **no
# saca su monto de una tarifa** — ajustar a mano es su propósito, así que trabar
# las líneas sería trabar lo que el documento viene a hacer. El control va donde
# se mueve la plata: al emitir, que es cuando el saldo del cliente cambia.
#
# Y con cuatro ojos: una nota de crédito es plata que se le devuelve al cliente,
# así que no la emite quien la armó.
class EmisionNotaAutorizadaTest < ActionDispatch::IntegrationTest
  setup do
    @cliente = clientes(:juan)
    @venta = ventas(:pendiente_juan)
    @creador = users(:admin)
    @supervisor = User.create!(
      nombre: "Supervisora Caja", email_address: "supnota@cec.test", password: "password123",
      rol: "supervisor_caja", ubicacion: "honduras", pin: "1234"
    )
    login(@supervisor)
  end

  # ── Nota de crédito: plata que se devuelve ──────────────────────────────

  test "sin PIN la nota no se emite y el saldo no se toca" do
    nc = nota_credito
    saldo_previo = @cliente.reload.saldo_pendiente

    post emitir_nota_credito_url(nc)

    assert_equal "creado", nc.reload.estado
    assert_equal saldo_previo, @cliente.reload.saldo_pendiente
    assert_equal 0, Autorizacion.count
  end

  test "con PIN correcto emite, baja el saldo y deja registro" do
    nc = nota_credito
    saldo_previo = @cliente.reload.saldo_pendiente.to_d

    assert_difference("Autorizacion.count", 1) do
      emitir_nc(nc, motivo: "Paquete llego danado")
    end

    assert_equal "emitido", nc.reload.estado
    # `emitir!` no deja el saldo en negativo — si la nota supera lo que el
    # cliente debe, queda en cero.
    assert_equal [ saldo_previo - nc.total.to_d, BigDecimal("0") ].max,
                 @cliente.reload.saldo_pendiente.to_d

    a = Autorizacion.last
    assert_equal "emitir", a.accion
    assert_equal nc, a.documento
    assert_equal @supervisor, a.autorizado_por
    assert_equal nc.total, a.valor_nuevo, "queda cuanto se le devolvio al cliente"
    assert_equal "Paquete llego danado", a.motivo
  end

  test "con PIN incorrecto no emite ni deja registro" do
    nc = nota_credito

    assert_no_difference("Autorizacion.count") do
      emitir_nc(nc, motivo: "Nada", pin: "9999")
    end

    assert_equal "creado", nc.reload.estado
  end

  test "sin motivo no se emite" do
    nc = nota_credito

    assert_no_difference("Autorizacion.count") do
      emitir_nc(nc, motivo: "")
    end
    assert_equal "creado", nc.reload.estado
  end

  # ── Cuatro ojos ─────────────────────────────────────────────────────────

  test "quien creo la nota no puede emitirla el mismo" do
    # El supervisor arma la nota y después intenta autorizarla con su propio PIN.
    nc = nota_credito(creado_por: @supervisor)

    assert_no_difference("Autorizacion.count") do
      emitir_nc(nc, motivo: "Me la apruebo solo")
    end

    assert_equal "creado", nc.reload.estado
    assert_match(/otra persona/, flash[:alert].to_s)
  end

  test "otro supervisor si puede emitirla" do
    nc = nota_credito(creado_por: @supervisor)
    otro = User.create!(
      nombre: "Otra Supervisora", email_address: "supnota2@cec.test", password: "password123",
      rol: "supervisor_prefactura", ubicacion: "honduras", pin: "4321"
    )

    emitir_nc(nc, motivo: "Revisado", autorizado_por_id: otro.id, pin: "4321")

    assert_equal "emitido", nc.reload.estado
  end

  test "el modal no ofrece a quien creo la nota" do
    otra = User.create!(
      nombre: "Supervisora Disponible", email_address: "supdisp@cec.test",
      password: "password123", rol: "supervisor_prefactura", ubicacion: "honduras", pin: "7777"
    )
    nc = nota_credito(creado_por: @supervisor)

    get nota_credito_url(nc)

    assert_response :success
    # El nombre suelto no sirve: el usuario logueado sale en el sidebar. Se
    # busca el formato de la opción del select.
    assert_match "#{otra.nombre} — #{otra.rol_label}", response.body
    assert_no_match(/#{@supervisor.nombre} — #{@supervisor.rol_label}/, response.body,
                    "quien creo la nota no debe aparecer en la lista de autorizantes")
  end

  # ── Nota de débito ──────────────────────────────────────────────────────

  test "la nota de debito tambien pide PIN al emitir" do
    nd = NotaDebito.build_from_paquetes(
      @venta, paquete_ids: [ paquetes(:disponible_entrega_juan).id ],
      motivo: "ajuste_manual", user: @creador
    )
    nd.save!

    post emitir_nota_debito_url(nd)
    assert_equal "creado", nd.reload.estado, "sin PIN no se emite"

    post emitir_nota_debito_url(nd), params: { autorizacion: {
      autorizado_por_id: @supervisor.id, pin: "1234", motivo: "Peso adicional confirmado"
    } }

    assert_equal "emitido", nd.reload.estado
    assert_equal "emitir", Autorizacion.last.accion
  end

  # ── La bitácora los muestra juntos ──────────────────────────────────────

  test "la bitacora suma aparte lo devuelto por notas de credito" do
    nc = nota_credito
    emitir_nc(nc, motivo: "Paquete llego danado")

    get autorizaciones_url

    assert_response :success
    assert_match "Notas de credito emitidas", response.body
    assert_match "Paquete llego danado", response.body
    assert_match nc.numero, response.body
  end

  private

  def login(user)
    delete session_url
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  def nota_credito(creado_por: @creador)
    NotaCredito.build_from_paquetes(
      @venta, paquete_ids: [ paquetes(:disponible_entrega_juan).id ],
      motivo: "devolucion", user: creado_por
    ).tap(&:save!)
  end

  def emitir_nc(nc, motivo:, pin: "1234", autorizado_por_id: nil)
    post emitir_nota_credito_url(nc), params: { autorizacion: {
      autorizado_por_id: autorizado_por_id || @supervisor.id, pin: pin, motivo: motivo
    } }
  end
end
