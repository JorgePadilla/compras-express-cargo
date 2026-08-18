require "test_helper"

# El paquete fantasma.
#
# Al crear una pre-alerta, `crear_paquete_esperado` materializa un `Paquete` en
# `pre_alerta_estado`. Cuando el bulto llega, `/etiquetar` no crea otro: encuentra
# el esperado y lo transiciona. **`create_single` lo hacía; `create_split` no.**
#
# Así que un tracking pre-alertado que llegaba dividido dejaba tres paquetes con
# el mismo tracking: las dos cajas reales y el esperado, huérfano. Consecuencias
# medidas antes del arreglo:
#
#   · `etiqueta?hermanas=1` sacaba **3 etiquetas para 2 cajas**, y la de más
#     salía con `—` donde va el número de recepción (nunca tuvo uno).
#   · el Warehouse Receipt declaraba **3 piezas**.
#   · la pre-alerta se quedaba en `pre_alerta` para siempre: el cliente la veía
#     "en camino" con el paquete ya en Miami.
#
# Y no se reparaba solo: `link_tracking!` filtra por `sin_vincular`
# (`paquete_id: nil`) y esa fila **ya apuntaba** al fantasma — invisible para su
# propio reparador.
class SplitReconciliaLaPreAlertaTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: {
      email_address: users(:digitador).email_address, password: "password123"
    }
    abrir_sesion_de_etiquetado
  end

  test "el paquete esperado se vuelve la Caja 1" do
    pap = pre_alertar("1Z999FANTASMA0001")
    esperado = pap.paquete

    postear_split(pap.tracking)

    cajas = Paquete.where(tracking: pap.tracking).order(:numero_caja)
    assert_equal 2, cajas.size, "quedó un fantasma al lado de las cajas"
    assert_equal esperado.id, cajas.first.id, "la Caja 1 no es el paquete esperado"
    assert_equal [ 1, 2 ], cajas.map(&:numero_caja)
    assert_equal "recibido_miami", cajas.first.estado
  end

  test "la pre-alerta sigue apuntando a la Caja 1 y avanza a recibido" do
    # Avanza sola: `after_save :sync_pre_alerta_estados` dispara porque el
    # esperado cambió de estado. No hace falta código nuevo — hacía falta que el
    # registro fuera el mismo.
    pap = pre_alertar("1Z999FANTASMA0002")

    postear_split(pap.tracking)

    caja1 = Paquete.where(tracking: pap.tracking).order(:numero_caja).first
    assert_equal caja1.id, pap.reload.paquete_id
    assert_equal "recibido", pap.pre_alerta.reload.estado
  end

  test "la Caja 1 conserva su guia y su numero de recepcion sale del madre" do
    # Conservar el id es la mitad; la otra es que la bitácora y la guía que el
    # cliente ya vio no cambien debajo de él.
    pap = pre_alertar("1Z999FANTASMA0003")
    guia_original = pap.paquete.guia

    postear_split(pap.tracking)

    cajas = Paquete.where(tracking: pap.tracking).order(:numero_caja)
    assert_equal guia_original, cajas.first.guia
    assert_equal 1, cajas.map(&:numero_recepcion).uniq.size, "las cajas no comparten el número madre"
    assert cajas.first.numero_recepcion.present?, "la Caja 1 se quedó sin número de recepción"
    assert_equal 1, cajas.map(&:warehouse_receipt_id).uniq.size
  end

  test "el tracking del cliente manda, y lo escaneado queda de secundario" do
    # PR-C6.21: el cliente pre-alerta la cola —"el tracking de USPS solo es
    # desde donde dice 92"— y la pistola lee el código largo. El que él tiene en
    # la mano es por el que va a preguntar, así que ese se conserva.
    pap = pre_alertar("9205590000000000000001")
    largo = "420331289205590000000000000001"

    postear_split(largo)

    cajas = Paquete.where(tracking: pap.tracking).order(:numero_caja)
    assert_equal 2, cajas.size
    assert_equal [ pap.tracking ], cajas.map(&:tracking).uniq
    assert_equal [ largo ], cajas.map(&:tracking_secundario).uniq,
                 "las N cajas tienen que encontrarse volviendo a escanear"
  end

  test "sin pre-alerta, un split nace igual que siempre" do
    assert_difference "Paquete.count", 2 do
      postear_split("1Z999SINPREALERTA1")
    end

    cajas = Paquete.where(tracking: "1Z999SINPREALERTA1").order(:numero_caja)
    assert_equal [ 1, 2 ], cajas.map(&:numero_caja)
    assert_nil cajas.first.tracking_secundario
  end

  test "un tracking que ya se recibio NO se reusa: es un duplicado, no un esperado" do
    # Solo se reconcilia contra lo que está **esperando**. Un tracking que ya
    # entró es el caso del modal de repetido —el courier recicla números— y
    # reusarlo sería pisar un paquete que ya se etiquetó, se pesó y quizás ya se
    # cobró.
    pap = pre_alertar("1Z999YARECIBIDO01")
    ya_recibido = pap.paquete
    ya_recibido.update!(estado: "recibido_miami", peso: 99)

    assert_difference "Paquete.count", 2 do
      postear_split(pap.tracking)
    end

    assert_equal 99.0, ya_recibido.reload.peso.to_f, "le pisaron el peso a un paquete ya recibido"
    assert_nil ya_recibido.numero_caja, "lo metieron de caja a un split al que no pertenece"
  end

  test "un solo bulto pre-alertado sigue reconciliando" do
    # El camino que ya funcionaba. Está acá porque ahora los dos comparten la
    # misma regla: si se rompe, se rompe para los dos.
    pap = pre_alertar("1Z999UNSOLOBULTO1")
    esperado = pap.paquete

    assert_no_difference "Paquete.count" do
      post etiquetar_url, params: { paquete: datos_base.merge(tracking: pap.tracking) }
    end

    assert_equal "recibido_miami", esperado.reload.estado
    assert_equal esperado.id, pap.reload.paquete_id
  end

  private

  def abrir_sesion_de_etiquetado
    post iniciar_sesion_etiquetar_url, params: {
      tipo_envio_id: tipo_envios(:cer).id, sucursal_recepcion_id: sucursales(:miami).id
    }
  end

  def pre_alertar(tracking)
    pa = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                           titulo: "Pre-alerta de prueba", estado: "pre_alerta")
    pa.pre_alerta_paquetes.create!(tracking: tracking, descripcion: "Lo que viene")
  end

  def datos_base
    { cliente_id: clientes(:juan).id, descripcion: "Dos cajas", peso: 10 }
  end

  def postear_split(tracking)
    post etiquetar_url, params: {
      paquete: datos_base.merge(tracking: tracking,
                                cajas: { "1" => { peso: 12.5 }, "2" => { peso: 30 } })
    }
  end
end
