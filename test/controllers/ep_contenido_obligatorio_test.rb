require "test_helper"

# PR: Yusef, probando staging — *"entrega personal, es obligatorio poner
# contenido, y debería ir más arriba, después de tipo de envío"*.
#
# Un paquete de courier llega con la descripción que le puso el carrier. El que
# entra al mostrador de Miami no trae nada escrito: si nadie lo teclea, la
# etiqueta y el Warehouse Receipt salen diciendo cuánto pesa pero no qué es.
#
# Va como test de integración —y no de sistema— porque **CI no corre
# `test/system`**: la regla tiene que quedar amarrada donde sí se corre.
class EpContenidoObligatorioTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: {
      email_address: users(:digitador).email_address, password: "password123"
    }
  end

  # ── El camino de una sola caja (`create_single`) ─────────────────────────

  test "sin contenido no se registra la entrega personal" do
    assert_no_difference "Paquete.count" do
      post entrega_personal_index_url, params: { paquete: attrs.except(:descripcion) }
    end

    assert_response :unprocessable_entity
  end

  test "el contenido en blanco tampoco pasa" do
    # La pistola y el copy/paste dejan espacios; `presence` los cuenta como
    # vacío, y acá se fija que sea así de verdad.
    assert_no_difference "Paquete.count" do
      post entrega_personal_index_url, params: { paquete: attrs.merge(descripcion: "   ") }
    end

    assert_response :unprocessable_entity
  end

  test "con contenido se registra" do
    assert_difference "Paquete.count" do
      post entrega_personal_index_url, params: { paquete: attrs }
    end
  end

  # ── El camino del split (`create_split`) ────────────────────────────────
  #
  # Son dos métodos distintos del controller y ya se separaron antes: uno
  # reconcilia la pre-alerta y el otro no. Si la regla solo agarra en uno,
  # basta con agregar una caja para saltársela.

  test "un split sin contenido tampoco se registra" do
    assert_no_difference "Paquete.count" do
      post entrega_personal_index_url, params: {
        paquete: attrs.except(:descripcion).merge(cajas: { "1" => { peso: 5 }, "2" => { peso: 8 } })
      }
    end

    assert_response :unprocessable_entity
  end

  test "un split con contenido se registra completo" do
    assert_difference "Paquete.count", 2 do
      post entrega_personal_index_url, params: {
        paquete: attrs.merge(cajas: { "1" => { peso: 5 }, "2" => { peso: 8 } })
      }
    end
  end

  # ── El alcance ──────────────────────────────────────────────────────────

  test "un paquete de courier sigue sin necesitar contenido" do
    # La regla es de Entrega Personal, no del sistema entero: /etiquetar recibe
    # cajas de Amazon todo el día y nadie las describe a mano.
    paquete = Paquete.new(tracking: "1Z999COURIER01", cliente: clientes(:juan),
                          tipo_envio: tipo_envios(:cer), proveedor: proveedores(:Amazon),
                          sucursal: sucursales(:zeron_sps), estado: "recibido_miami")

    assert paquete.valid?, paquete.errors.full_messages.to_sentence
  end

  test "una entrega personal que YA estaba sin contenido se sigue pudiendo guardar" do
    # La trampa de siempre —la misma del método de prepago y la del
    # consolidado—: si la validación corriera en cada guardado, abrir un EP
    # viejo para corregirle el remitente lo trabaría con un error de algo que
    # nadie tocó.
    post entrega_personal_index_url, params: { paquete: attrs }
    viejo = Paquete.order(:id).last
    viejo.update_column(:descripcion, nil)

    viejo = Paquete.find(viejo.id)
    viejo.remitente = "se le corrige el remitente"

    assert viejo.valid?, viejo.errors.full_messages.to_sentence
    assert viejo.save
  end

  test "pero vaciarle el contenido a uno que lo tiene si se traba" do
    post entrega_personal_index_url, params: { paquete: attrs }
    paquete = Paquete.order(:id).last

    paquete.descripcion = ""

    assert_not paquete.valid?
  end

  test "el error nombra el campo como lo ve el que recibe" do
    # En la pantalla el rótulo dice **Contenido**; el modelo lo llama
    # `descripcion`. Un error que diga "Descripcion" manda a Yusef a buscar un
    # campo que no existe.
    paquete = Paquete.new(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                          proveedor: proveedores(:driver_entrega),
                          sucursal_recepcion: sucursales(:miami), estado: "recibido_miami")
    paquete.valid?

    assert_match(/Contenido/, paquete.errors.full_messages.to_sentence)
  end

  # ── Dónde queda en la pantalla ──────────────────────────────────────────

  test "el contenido va arriba, entre el tipo de envio y el peso" do
    # Estaba hasta abajo: el que recibe llenaba todo el cálculo de peso y cajas
    # antes de toparse con el único campo que dice **qué** está midiendo.
    get new_entrega_personal_url
    assert_response :success

    tipo_envio = response.body.index("paquete[tipo_envio_id]")
    contenido  = response.body.index("paquete[descripcion]")
    cajas      = response.body.index("Medidas (pulgadas)")

    assert tipo_envio && contenido && cajas, "faltó uno de los tres bloques en la pantalla"
    assert contenido > tipo_envio, "el Contenido quedó antes del tipo de envío"
    assert contenido < cajas, "el Contenido volvió a caer debajo del peso y las cajas"
  end

  test "el navegador tampoco deja mandarlo vacio" do
    # El servidor ya lo rechaza, pero cada rechazo quema un número del contador
    # EP: `generate_ep_tracking` corre en `before_validation`, fuera de la
    # transacción. El `required` hace que ese camino sea el raro.
    get new_entrega_personal_url

    # Ojo: Rails escribe `name` **al final** de la etiqueta, así que el regex no
    # puede dar por sentado el orden de los atributos (ya mordió dos veces).
    campo = response.body[/<textarea[^>]*paquete\[descripcion\][^>]*>/]
    assert campo, "no se encontró el textarea de Contenido"
    assert_match(/required/, campo, "el campo Contenido perdió el `required`")
  end

  private

  def attrs
    {
      cliente_id: clientes(:juan).id,
      tipo_envio_id: tipo_envios(:cer).id,
      proveedor_id: proveedores(:driver_entrega).id,
      sucursal_recepcion_id: sucursales(:miami).id,
      peso: 10,
      descripcion: "Dos pares de zapatos"
    }
  end
end
