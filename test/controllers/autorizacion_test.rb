require "test_helper"

# PR-13.d: el candado y la autorización por línea.
#
# Yusef: "queremos que el área de los precios estén establecidos, listo. No hay
# nada más, no se puede hacer más si está todo preestablecido. Ahora, si lo
# quieren modificar, ellos tienen que pedir autorización — ahí es donde entra un
# jefe, un supervisor, y ahí es donde llega y pone un código especial de él."
class AutorizacionTest < ActionDispatch::IntegrationTest
  setup do
    TarifasPropuesta2026.sembrar!
    @cliente = clientes(:juan)
    @cajero = users(:cajero)
    @supervisor = User.create!(
      nombre: "Supervisora", email_address: "sup13d@cec.test", password: "password123",
      rol: "supervisor_prefactura", ubicacion: "honduras", pin: "1234"
    )
    login(@cajero)
    @pf = pre_factura_con(peso: 10)     # 10 lb CER → L.111.83/lb, L.1,118.30
    @item = @pf.pre_factura_items.first
  end

  # ── El candado: es el punto de todo esto ────────────────────────────────

  test "un PATCH directo no puede cambiar el precio" do
    patch pre_factura_url(@pf), params: { pre_factura: {
      pre_factura_items_attributes: { "0" => { id: @item.id, precio_libra: 1.00 } }
    } }

    assert_equal BigDecimal("111.83"), @item.reload.precio_libra,
                 "el precio tiene que salir preestablecido y no moverse sin autorizacion"
  end

  test "un PATCH directo no puede cambiar el peso ni el subtotal ni el descuento" do
    patch pre_factura_url(@pf), params: { pre_factura: {
      pre_factura_items_attributes: { "0" => {
        id: @item.id, peso_cobrar: 1, subtotal: 5, descuento_monto: 900
      } }
    } }

    @item.reload
    assert_equal BigDecimal("10.0"), @item.peso_cobrar
    assert_equal BigDecimal("1118.30"), @item.subtotal
    assert_equal BigDecimal("0"), @item.descuento_monto
  end

  test "un PATCH directo no puede quitar una linea" do
    assert_no_difference("PreFacturaItem.count") do
      patch pre_factura_url(@pf), params: { pre_factura: {
        pre_factura_items_attributes: { "0" => { id: @item.id, _destroy: "1" } }
      } }
    end
  end

  test "el candado tambien aplica al admin" do
    login(users(:admin))

    patch pre_factura_url(@pf), params: { pre_factura: {
      pre_factura_items_attributes: { "0" => { id: @item.id, precio_libra: 1.00 } }
    } }

    assert_equal BigDecimal("111.83"), @item.reload.precio_libra,
                 "si el admin edita suelto, el registro tiene un agujero"
  end

  test "el concepto si se puede editar — es la descripcion, no el monto" do
    patch pre_factura_url(@pf), params: { pre_factura: {
      pre_factura_items_attributes: { "0" => { id: @item.id, concepto: "Flete corregido" } }
    } }

    assert_equal "Flete corregido", @item.reload.concepto
  end

  # ── Autorizar y cambiar son el mismo acto ───────────────────────────────

  test "con PIN correcto aplica el descuento y lo registra" do
    assert_difference("Autorizacion.count", 1) do
      autorizar(accion: "descuento", valor: 10, modo: "porcentaje", motivo: "Cliente frecuente")
    end

    @item.reload
    assert_equal BigDecimal("111.83"), @item.descuento_monto
    assert_equal BigDecimal("10.0"), @item.descuento_porcentaje
    assert_equal "Cliente frecuente", @item.descuento_motivo
    assert_equal BigDecimal("111.83"), @pf.reload.descuento, "los totales se recalculan"

    a = Autorizacion.last
    assert_equal @supervisor, a.autorizado_por
    assert_equal @cajero, a.solicitado_por
    assert_equal BigDecimal("0"), a.valor_anterior
    assert_equal "Cliente frecuente", a.motivo
  end

  test "con PIN incorrecto no cambia nada ni deja registro" do
    assert_no_difference("Autorizacion.count") do
      autorizar(accion: "precio", valor: 1.00, motivo: "Nada", pin: "9999")
    end

    assert_equal BigDecimal("111.83"), @item.reload.precio_libra,
                 "aplicar y registrar son atomicos: o las dos cosas o ninguna"
  end

  test "un cajero no autoriza aunque mande un PIN valido de otro" do
    otro = User.create!(
      nombre: "Cajero con PIN", email_address: "cajpin@cec.test", password: "password123",
      rol: "cajero", ubicacion: "honduras", pin: "5555"
    )

    assert_no_difference("Autorizacion.count") do
      autorizar(accion: "precio", valor: 1.00, motivo: "Nada",
                autorizado_por_id: otro.id, pin: "5555")
    end
    assert_equal BigDecimal("111.83"), @item.reload.precio_libra
  end

  test "sin motivo no se autoriza — es el punto del registro" do
    assert_no_difference("Autorizacion.count") do
      autorizar(accion: "precio", valor: 1.00, motivo: "")
    end
    assert_equal BigDecimal("111.83"), @item.reload.precio_libra
  end

  test "autoriza cambiar el precio y guarda contra que valor se autorizo" do
    autorizar(accion: "precio", valor: 90.00, motivo: "Ajuste pactado")

    assert_equal BigDecimal("90.00"), @item.reload.precio_libra
    a = Autorizacion.last
    assert_equal BigDecimal("111.83"), a.valor_anterior,
                 "sin el valor original la auditoria no reconstruye nada"
    assert_equal BigDecimal("90.00"), a.valor_nuevo
  end

  test "autoriza cambiar el peso a cobrar" do
    autorizar(accion: "peso", valor: 8, motivo: "Se repeso")

    assert_equal BigDecimal("8.0"), @item.reload.peso_cobrar
  end

  test "autoriza quitar la linea y el registro sobrevive" do
    concepto = @item.concepto

    assert_difference("PreFacturaItem.count", -1) do
      autorizar(accion: "eliminar", motivo: "Se entrego por aparte")
    end

    a = Autorizacion.last
    assert_nil a.pre_factura_item_id, "la linea ya no existe"
    assert_equal concepto, a.concepto, "pero el registro guarda de cual se trataba"
    assert_equal @pf, a.documento
  end

  # ── Fuerza bruta ────────────────────────────────────────────────────────

  test "seis intentos fallidos bloquean a ese supervisor" do
    6.times { autorizar(accion: "precio", valor: 1, motivo: "x", pin: "0000") }

    assert_match(/Demasiados intentos/, flash[:alert].to_s)
  end

  test "el bloqueo es por supervisor y no por la maquina" do
    # En un mostrador todos comparten la IP: si el limite fuera por IP —que es
    # el default de Rails— quien se equivoca dejaria afuera a los demas y el
    # cajero legitimo se comeria el bloqueo.
    otro = User.create!(
      nombre: "Otro Supervisor", email_address: "sup13d2@cec.test", password: "password123",
      rol: "supervisor_caja", ubicacion: "honduras", pin: "4321"
    )

    6.times { autorizar(accion: "precio", valor: 1, motivo: "x", pin: "0000") }

    autorizar(accion: "precio", valor: 95.00, motivo: "Ajuste",
              autorizado_por_id: otro.id, pin: "4321")

    assert_equal BigDecimal("95.00"), @item.reload.precio_libra,
                 "el otro supervisor tiene que poder seguir autorizando"
  end

  # ── La bitácora ─────────────────────────────────────────────────────────

  test "la bitacora muestra lo autorizado y solo la ven los supervisores" do
    autorizar(accion: "descuento", valor: 10, modo: "porcentaje", motivo: "Cliente frecuente")

    get autorizaciones_url
    assert_redirected_to root_path, "un cajero no revisa las autorizaciones"

    login(@supervisor)
    get autorizaciones_url

    assert_response :success
    assert_match "Cliente frecuente", response.body
    assert_match @supervisor.nombre, response.body
    assert_match "111.83", response.body
  end

  private

  def login(user)
    delete session_url
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  def autorizar(accion:, motivo:, valor: nil, modo: nil, pin: "1234", autorizado_por_id: nil)
    post pre_factura_item_autorizacion_url(@pf, @item), params: {
      autorizacion: {
        accion: accion, valor: valor, modo: modo, motivo: motivo,
        autorizado_por_id: autorizado_por_id || @supervisor.id, pin: pin
      }
    }
  end

  def pre_factura_con(peso:)
    paquete = Paquete.create!(
      tracking: "AUT#{SecureRandom.hex(3)}",
      cliente: @cliente, tipo_envio: tipo_envios(:cer), sucursal: sucursales(:zeron_sps),
      estado: "disponible_entrega", peso: peso, peso_cobrar: peso,
      cantidad_productos: 1, cantidad_paquetes: 1,
      descripcion: "Paquete de prueba", user: users(:digitador)
    )
    PreFactura.build_from_paquetes(@cliente, [ paquete.id ], user: @cajero).tap(&:save!)
  end
end
