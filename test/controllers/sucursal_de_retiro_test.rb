require "test_helper"

# PR-C6.37: dónde retira el cliente, como dato y no como texto libre.
#
# Yusef, 2026-08-08, explicando por qué Miami tiene que separar las cajas:
#
#   "Recordá que **la ciudad donde es la persona no es el mismo lugar donde se
#    le entrega**. La idea es ponerle **dónde el hombre va a querer su retiro**."
#
# Y sobre el campo, cuando Jorge le mostró el que ya existía en el paquete:
#
#   Jorge: "Ah, pero este es el que tengo acá, retiro."
#   Yusef: "Sí, sí, por eso, ese mismo — **no es que vas a crear algo más**."
#
# Tenía razón: `paquete.sucursal_id` ya existía. Lo que **nadie llenaba** era
# eso en /etiquetar, así que la etiqueta caía al `ciudad` del cliente — texto
# libre. Con eso, "Tegus" y "Tegucigalpa" son dos bolsas distintas en Miami, y
# separar por sucursal deja de servir.
#
# Lo que faltaba entonces no era el campo del paquete: era el **default del
# cliente**, que es literalmente lo que él describe.
class SucursalDeRetiroTest < ActionDispatch::IntegrationTest
  setup do
    @tgu = sucursales(:humuya_tgu)
    @cliente = clientes(:juan)
    @cliente.update!(sucursal_retiro: @tgu)
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: tipo_envios(:cer).id, sucursal_recepcion_id: sucursales(:miami).id }
  end

  test "el paquete etiquetado hereda la sucursal del cliente" do
    post etiquetar_url, params: { paquete: attrs }

    assert_equal @tgu.id, Paquete.last.sucursal_id
  end

  test "las cajas de un split la heredan tambien" do
    post etiquetar_url, params: { paquete: attrs.merge(cantidad_paquetes: 3) }

    assert_equal [ @tgu.id ] * 3, Paquete.order(:id).last(3).map(&:sucursal_id)
  end

  test "un paquete esperado que ya trae sucursal la conserva" do
    # La del cliente es un DEFAULT, no una imposicion. `/etiquetar` no deja que
    # Miami elija donde retira el cliente —y esta bien: no es su decision— pero
    # un paquete que ya venia con una no se pisa.
    otra = sucursales(:zeron_sps)
    pap = pre_alertas(:activa).pre_alerta_paquetes.create!(
      tracking: "RETESPERADO01", descripcion: "Cosas"
    )
    pap.reload.paquete.update_columns(sucursal_id: otra.id)

    post etiquetar_url, params: { paquete: attrs.merge(tracking: "RETESPERADO01") }

    assert_equal otra.id, pap.reload.paquete.reload.sucursal_id
  end

  test "un cliente sin sucursal asignada no rompe nada" do
    @cliente.update!(sucursal_retiro: nil)

    post etiquetar_url, params: { paquete: attrs }

    assert_nil Paquete.last.sucursal_id
  end

  test "el nombre para Miami sale de la sucursal, no de la ciudad" do
    @cliente.update!(ciudad: "Tegus")

    assert_equal @tgu.nombre, @cliente.reload.sucursal_retiro_nombre
  end

  test "mientras no tenga sucursal, cae a la ciudad" do
    # No empeora nada: es lo que la etiqueta ya venía imprimiendo. Solo deja de
    # ser lo único que hay.
    @cliente.update!(sucursal_retiro: nil, ciudad: "Tegucigalpa")

    assert_equal "Tegucigalpa", @cliente.reload.sucursal_retiro_nombre
  end

  test "el aviso de /etiquetar usa la sucursal de verdad" do
    @cliente.update!(ciudad: "Tegus")

    get buscar_clientes_url(q: @cliente.codigo)

    encontrado = JSON.parse(response.body).find { |c| c["id"] == @cliente.id }
    assert_equal @tgu.nombre, encontrado["sucursal_retiro"]
  end

  test "el admin la puede asignar desde la ficha del cliente" do
    admin = users(:admin)
    post session_url, params: { email_address: admin.email_address, password: "password123" }

    patch cliente_url(@cliente), params: { cliente: { sucursal_retiro_id: sucursales(:zeron_sps).id } }

    assert_equal sucursales(:zeron_sps).id, @cliente.reload.sucursal_retiro_id
  end

  test "Miami no se ofrece como lugar de retiro" do
    # Nadie retira en Miami: es donde se recibe. Ofrecerla invitaría a un error
    # que después manda la caja a la bolsa equivocada.
    admin = users(:admin)
    post session_url, params: { email_address: admin.email_address, password: "password123" }

    get edit_cliente_url(@cliente)

    select = response.body[/name="cliente\[sucursal_retiro_id\]".*?<\/select>/m].to_s
    assert_match @tgu.nombre, select
    assert_no_match(/#{sucursales(:miami).nombre}/, select)
  end

  private

  def attrs
    {
      tracking: "RET#{SecureRandom.hex(4)}",
      cliente_id: @cliente.id,
      descripcion: "Paquete de prueba",
      peso: 5
    }
  end
end
