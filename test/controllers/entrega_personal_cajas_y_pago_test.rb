require "test_helper"

# C20-07 y C20-08, las dos cosas que Entrega Personal le debía a la etiqueta.
#
# **Las cajas** (C20-07). Jorge: *"esta lógica de las cajas que hicimos para
# etiquetar también hay que aplicarla en entrega personal"*. Acá la cantidad
# salía SOLO de las filas que el operario agregara, y en Entrega Personal casi
# nunca se pesa ni se mide: un envío de tres bultos no tenía cómo pedir tres
# etiquetas, siempre se grababa uno.
#
# **El pago** (C20-08). Yusef: *"sí, es la misma la etiqueta, idénticas, no
# cambia, pero en la entrega personal y recolectas va **si va bien pagada o no
# viene pagada**, si le marcamos la opción de que se pagó o no se pagó"*.
class EntregaPersonalCajasYPagoTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:digitador)
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @proveedor = Proveedor.where(tipo: "entrega_personal").activos.ordered.first
  end

  # ── C20-07 · las cajas ──

  test "sin medir nada, la cantidad del modal manda" do
    post entrega_personal_index_url, params: base.merge(etiquetas: 3)

    cajas = Paquete.order(:id).last(3)
    assert_equal 1, cajas.map(&:tracking).uniq.size, "las tres son el mismo envío"
    assert_equal [ 1, 2, 3 ], cajas.map(&:numero_caja)
    assert_equal [ 3, 3, 3 ], cajas.map(&:cantidad_paquetes)
    assert_equal 1, cajas.map(&:numero_recepcion).uniq.size
  end

  test "sin contestar nada sigue siendo un solo bulto" do
    assert_difference "Paquete.count", 1 do
      post entrega_personal_index_url, params: base
    end
  end

  test "una cantidad fuera de rango avisa y no graba" do
    assert_no_difference "Paquete.count" do
      post entrega_personal_index_url, params: base.merge(etiquetas: 500)
    end
    assert_response :unprocessable_entity
    assert_match(/entre 1 y 99/i, response.body)
  end

  test "si midió cajas, mandan las filas y no el modal" do
    post entrega_personal_index_url, params: base.merge(
      etiquetas: 7,
      paquete: base[:paquete].merge(
        cajas: { "1" => { peso: "5" }, "2" => { peso: "8" } }
      )
    )

    cajas = Paquete.order(:id).last(2)
    assert_equal [ 1, 2 ], cajas.map(&:numero_caja), "las filas son la fuente cuando existen"
    assert_equal [ 5, 8 ], cajas.map { |c| c.peso.to_i }
  end

  test "el modal de cantidad está en la pantalla" do
    get new_entrega_personal_url

    assert_response :success
    assert_match "entrega_personal_target=\"etiquetasModal\"", response.body.gsub("data-entrega-personal-target", "entrega_personal_target")
    assert_match(/cuántas etiquetas se imprimen/i, response.body)
  end

  # ── C20-08 · el pago en la etiqueta ──

  test "una entrega personal pagada imprime PAGADO" do
    post entrega_personal_index_url, params: base.merge(
      paquete: base[:paquete].merge(prepagado_miami: "1", prepagado_miami_metodo: "zelle")
    )
    paquete = Paquete.order(:id).last
    assert paquete.prepagado_miami?

    get etiqueta_paquete_url(paquete)

    assert_match 'data-campo="pago"', response.body
    assert_match "PAGADO", response.body
    assert_no_match(/NO PAGADO/, response.body)
  end

  test "una entrega personal sin pagar lo dice: NO PAGADO" do
    post entrega_personal_index_url, params: base
    paquete = Paquete.order(:id).last

    get etiqueta_paquete_url(paquete)

    assert_match 'data-campo="pago"', response.body
    assert_match "NO PAGADO", response.body,
                 "el que entrega en Honduras tiene que poder leerlo y cobrar"
  end

  test "un paquete normal no lleva el renglón del pago" do
    # "Es la misma etiqueta, idénticas, no cambia" — el resto de la carga se
    # cobra por la pre-factura y decirlo en cada etiqueta sería ruido.
    get etiqueta_paquete_url(paquetes(:disponible_entrega_juan))

    assert_response :success
    assert_no_match(/data-campo="pago"/, response.body)
  end

  private

  def base
    {
      print: "true",
      paquete: {
        cliente_id: clientes(:juan).id,
        tipo_envio_id: tipo_envios(:cer).id,
        proveedor_id: @proveedor.id,
        sucursal_recepcion_id: Sucursal.de_recepcion.con_codigo_ep.first.id,
        descripcion: "Dos pares de zapatos",
        peso: 10
      }
    }
  end
end
