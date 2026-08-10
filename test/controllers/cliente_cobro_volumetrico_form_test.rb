require "test_helper"

# PR-C6.41 · RP-04b: la tarjeta "Cómo se le cobra" en la ficha del cliente.
#
# Yusef: *"es lo que le creamos al cliente, CUANDO CREAMOS EL CLIENTE... va a
# tener una opción para seleccionar varios tipos de envío y en cuál sí y en cuál
# no"*. Sirve al crear y al editar.
class ClienteCobroVolumetricoFormTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @cliente = clientes(:juan)
    @cem = tipo_envios(:cem)
    @cer = tipo_envios(:cer)
  end

  # ── El round-trip ──

  test "editar prende el flag en los servicios marcados" do
    patch cliente_url(@cliente), params: { cliente: {
      tipo_envio_solo_volumetrico_ids: [ @cem.id ]
    } }

    assert_redirected_to cliente_url(@cliente)
    assert_equal [ @cem.id ], @cliente.reload.tipo_envio_solo_volumetrico_ids
  end

  test "destildar todo apaga el flag" do
    # El otro lado del round-trip. Rails manda un "" oculto cuando no queda
    # ningun check marcado; si eso no llegara a `update`, el flag no se podria
    # apagar nunca desde la pantalla.
    @cliente.tipo_envio_solo_volumetricos << @cem

    patch cliente_url(@cliente), params: { cliente: {
      tipo_envio_solo_volumetrico_ids: [ "" ]
    } }

    assert_empty @cliente.reload.tipo_envio_solo_volumetrico_ids
  end

  test "crear un cliente ya con el flag puesto" do
    assert_difference "Cliente.count", 1 do
      post clientes_url, params: { cliente: {
        nombre: "Mayorista", apellido: "Grande",
        tipo_envio_solo_volumetrico_ids: [ @cem.id, @cer.id ]
      } }
    end

    assert_equal [ @cem.id, @cer.id ].sort, Cliente.last.tipo_envio_solo_volumetrico_ids.sort
  end

  # ── Los cuatro caminos que renderizan el form ──
  #
  # `create`/`update` re-renderizan el mismo form cuando falla una validacion,
  # SIN pasar por `new`/`edit`. Olvidar cargar el catalogo en esos dos caminos
  # revienta la pantalla justo cuando el usuario ya se equivoco. Ya paso dos
  # veces en este proyecto (PR-C6.26 y PR-C6.36).

  test "new trae los servicios" do
    get new_cliente_url

    assert_response :success
    assert_select "input[name=?][value=?]", "cliente[tipo_envio_solo_volumetrico_ids][]", @cem.id.to_s
  end

  test "edit trae los servicios" do
    get edit_cliente_url(@cliente)

    assert_response :success
    assert_select "input[name=?][value=?]", "cliente[tipo_envio_solo_volumetrico_ids][]", @cem.id.to_s
  end

  test "el re-render de create con error trae los servicios" do
    post clientes_url, params: { cliente: { nombre: "" } }

    assert_response :unprocessable_entity
    assert_select "input[name=?][value=?]", "cliente[tipo_envio_solo_volumetrico_ids][]", @cem.id.to_s
  end

  test "el re-render de update con error trae los servicios" do
    patch cliente_url(@cliente), params: { cliente: { nombre: "" } }

    assert_response :unprocessable_entity
    assert_select "input[name=?][value=?]", "cliente[tipo_envio_solo_volumetrico_ids][]", @cem.id.to_s
  end

  test "el edit trae marcados los que ya tiene" do
    @cliente.tipo_envio_solo_volumetricos << @cem

    get edit_cliente_url(@cliente)

    assert_select "input[name=?][value=?][checked]",
      "cliente[tipo_envio_solo_volumetrico_ids][]", @cem.id.to_s
    assert_select "input[name=?][value=?][checked]",
      "cliente[tipo_envio_solo_volumetrico_ids][]", @cer.id.to_s, count: 0
  end

  # ── El detalle ──

  test "el show dice en que servicios aplica" do
    @cliente.tipo_envio_solo_volumetricos << @cem

    get cliente_url(@cliente)

    assert_response :success
    assert_select "dd", text: /#{@cem.nombre}/
  end

  # ── El JSON del autocomplete ──

  test "buscar le manda la lista de servicios al panel de calculo" do
    @cliente.tipo_envio_solo_volumetricos << @cem

    get buscar_clientes_url, params: { q: @cliente.codigo }, as: :json

    fila = JSON.parse(response.body).find { |c| c["id"] == @cliente.id }
    assert_equal [ @cem.id ], fila["solo_volumetrico_en"],
      "sin esto /etiquetar muestra un peso a cobrar distinto del que factura la pre-factura"
  end

  test "buscar manda lista vacia para un cliente sin el trato" do
    get buscar_clientes_url, params: { q: @cliente.codigo }, as: :json

    fila = JSON.parse(response.body).find { |c| c["id"] == @cliente.id }
    assert_equal [], fila["solo_volumetrico_en"]
  end
end
