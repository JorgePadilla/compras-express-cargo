require "test_helper"

# PR: los campos de arriba son **una caja**, siempre la misma cosa.
#
# Jorge: *"cuando se pone la cantidad, digamos 2, luego se ingresa una caja, se
# puede volver a poner la cantidad digamos 1 — pero pusimos 2 al inicio. Es
# confuso"*.
#
# La causa: esos campos significaban dos cosas. Sin cajas agregadas **eran el
# paquete**; con cajas agregadas eran un borrador que se descartaba en silencio
# si no le dabas «Agregar». Ahora son siempre la caja que se está midiendo, y al
# guardar se agrega sola.
#
# Estos tests son de **integración a propósito**: CI corre `rails test`, que no
# incluye `test/system`. Lo que se puede fijar sin navegador se fija acá.
class CajaEnCursoTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    @cliente = clientes(:juan)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
  end

  # ── Que el auto-agregado no cambie lo que se guardaba ───────────────────

  test "una sola caja se guarda igual que antes, venga como venga" do
    # El caso del 95%: un bulto. Antes llegaba en los campos de arriba; con el
    # auto-agregado llega como `cajas[1]`. Tiene que dar lo mismo — un paquete,
    # con ese peso — o el cambio de UI habría movido lo que se cobra.
    iniciar_etiquetado

    assert_difference "Paquete.count", 1 do
      post etiquetar_url, params: { paquete: attrs.merge(
        cajas: { "1" => { peso: "7.5", alto: "3", largo: "4", ancho: "5", cantidad_productos: "2" } }
      ) }
    end

    p = Paquete.order(:id).last
    assert_equal 7.5, p.peso.to_f
    assert_equal 2, p.cantidad_productos
    assert_not p.dividido?, "una caja no es un split"
  end

  test "dos cajas se guardan con su peso propio" do
    iniciar_etiquetado

    assert_difference "Paquete.count", 2 do
      post etiquetar_url, params: { paquete: attrs.merge(
        cajas: { "1" => { peso: "5" }, "2" => { peso: "30" } }
      ) }
    end

    dos = Paquete.order(:id).last(2)
    assert_equal [ 5.0, 30.0 ], dos.map { |p| p.peso.to_f }.sort
    assert_equal 1, dos.map(&:tracking).uniq.size, "las dos cajas son el mismo tracking"
  end

  test "entrega personal hace lo mismo" do
    assert_difference "Paquete.count", 2 do
      post entrega_personal_index_url, params: { paquete: ep_attrs.merge(
        cajas: { "1" => { peso: "5" }, "2" => { peso: "30" } }
      ) }
    end

    dos = Paquete.order(:id).last(2)
    assert_equal [ 5.0, 30.0 ], dos.map { |p| p.peso.to_f }.sort
  end

  # ── Lo que la pantalla tiene que decir ──────────────────────────────────

  test "las dos pantallas rotulan el bloque como una caja" do
    # Es el arreglo entero en una línea de HTML: el bloque deja de ser anónimo.
    iniciar_etiquetado
    get etiquetar_url

    assert_response :success
    assert_select "[data-cajas-repetidor-target='rotuloCaja']", text: "Caja 1"

    get new_entrega_personal_url

    assert_response :success
    assert_select "[data-cajas-repetidor-target='rotuloCaja']", text: "Caja 1"
  end

  test "el aviso de la lista vacia ya no promete que se pierde" do
    # Decía "sin cajas agregadas: se guarda como un solo bulto". Con el
    # auto-agregado eso dejó de ser una excepción y pasó a ser la regla.
    iniciar_etiquetado
    get etiquetar_url

    assert_match(/aunque no le des «Agregar»/, response.body)
  end

  private

  def iniciar_etiquetado
    post iniciar_sesion_etiquetar_url,
         params: { tipo_envio_id: tipo_envios(:cer).id,
                   sucursal_recepcion_id: sucursales(:miami).id }
  end

  def attrs
    { cliente_id: @cliente.id, tracking: "1Z#{SecureRandom.hex(5).upcase}",
      descripcion: "Caja de prueba", peso: 1 }
  end

  def ep_attrs
    { cliente_id: @cliente.id, tipo_envio_id: tipo_envios(:cer).id,
      sucursal_recepcion_id: sucursales(:miami).id,
      proveedor_id: proveedores(:driver_entrega).id,
      descripcion: "Caja de prueba", peso: 1 }
  end
end
