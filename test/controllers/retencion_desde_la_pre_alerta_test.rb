require "test_helper"

# La retención anunciada desde la pre-alerta, con sus motivos.
#
# Jorge, sobre `/pre_alertas/new`: *"retener en Miami debería comportarse igual
# que el de etiquetar y entrega personal, debería ser el mismo componente"*.
#
# `#305` había decidido que la pre-alerta llevara **solo la bandera** —*"el
# motivo se sabe cuando el paquete llega"*—. La razón real era evitarme una tabla
# de join, y resultó que no hacía falta: los motivos y la nota se guardan en el
# **paquete esperado**, que ya tiene esas columnas. Una sola fuente.
class RetencionDesdeLaPreAlertaTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: {
      email_address: users(:admin).email_address, password: "password123"
    }
    @motivos = [ motivos_retencion(:danado), motivos_retencion(:perecedero) ]
  end

  test "los motivos viajan al paquete esperado" do
    pa = crear_con_retencion(motivos: @motivos.map(&:id), notas: "Le falta la factura")
    esperado = pa.pre_alerta_paquetes.first.paquete

    assert esperado.retener_miami?
    assert_equal @motivos.map(&:id).sort, esperado.motivo_retencion_ids.sort
    assert_equal "Le falta la factura", esperado.notas_retencion
  end

  test "sin retencion no se le inventan motivos" do
    pa = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                           titulo: "Normal", estado: "pre_alerta")
    pap = pa.pre_alerta_paquetes.create!(tracking: "1ZSINRETENCION01", descripcion: "x")

    assert_not pap.paquete.retener_miami?
    assert_empty pap.paquete.motivo_retencion_ids
  end

  test "cambiar solo los motivos tambien llega al esperado" do
    # El caso que el dirty tracking de Rails **no ve**: los motivos no son
    # columnas de `pre_alerta_paquetes`, así que sin una bandera propia
    # `sync_paquete_esperado` salía temprano y no sincronizaba nada, en silencio.
    pa = crear_con_retencion(motivos: [ @motivos.first.id ], notas: "Uno")
    pap = pa.pre_alerta_paquetes.first

    pap.update!(motivo_retencion_ids: @motivos.map(&:id))

    assert_equal @motivos.map(&:id).sort, pap.paquete.reload.motivo_retencion_ids.sort
  end

  test "el formulario los lee de vuelta desde el esperado" do
    pa = crear_con_retencion(motivos: [ @motivos.last.id ], notas: "Detalle")
    pap = PreAlertaPaquete.find(pa.pre_alerta_paquetes.first.id)

    assert_equal [ @motivos.last.id ], pap.motivo_retencion_ids
    assert_equal "Detalle", pap.notas_retencion
  end

  test "una vez recibido en Miami, la pre-alerta ya no le pisa nada" do
    # La regla que ya existía: el operador es dueño del paquete desde que lo
    # recibe. Editar la pre-alerta después no le puede cambiar la retención que
    # él decidió.
    pa = crear_con_retencion(motivos: [ @motivos.first.id ], notas: "De la pre-alerta")
    pap = pa.pre_alerta_paquetes.first
    pap.paquete.update!(estado: "recibido_miami")

    pap.update!(motivo_retencion_ids: [ @motivos.last.id ], notas_retencion: "Otra cosa")

    assert_equal "De la pre-alerta", pap.paquete.reload.notas_retencion
  end

  test "el controller acepta los campos nuevos" do
    assert_difference "PreAlerta.count" do
      post pre_alertas_url, params: { pre_alerta: {
        cliente_id: clientes(:juan).id, tipo_envio_id: tipo_envios(:cer).id,
        titulo: "Por request", consolidado: false,
        pre_alerta_paquetes_attributes: {
          "0" => { tracking: "1ZPORREQUEST0001", descripcion: "x", retener_miami: "1",
                   motivo_retencion_ids: [ "", @motivos.first.id.to_s ],
                   notas_retencion: "Viene golpeado" }
        }
      } }
    end

    esperado = PreAlerta.last.pre_alerta_paquetes.first.paquete
    assert esperado.retener_miami?
    assert_equal [ @motivos.first.id ], esperado.motivo_retencion_ids
    assert_equal "Viene golpeado", esperado.notas_retencion
  end

  # ── Apagar la retención ────────────────────────────────────────────────

  test "desmarcar la retencion se lleva los motivos" do
    # `checkbox-modal` dice explícito que desmarcar **no** limpia los campos del
    # modal. Sin esto, el paquete quedaba sin retención y con "contenido
    # perecedero" colgado — el mismo dato falso que dejaba el prepago antes de
    # que su concern limpiara la rama `false`.
    paquete = Paquete.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                              tracking: "1ZAPAGARRETENCION", descripcion: "x",
                              estado: "recibido_miami", user: users(:admin),
                              sucursal_recepcion: sucursales(:miami),
                              retener_miami: true, motivo_retencion_ids: @motivos.map(&:id),
                              notas_retencion: "Estaba roto")

    paquete.update!(retener_miami: false)

    assert_empty paquete.reload.motivo_retencion_ids
    assert_nil paquete.notas_retencion
  end

  test "un paquete en estado retenido NO se queda sin motivos" do
    # `retenido` es un paso del pipeline, **otra cosa** que la bandera de Miami —
    # y ahí `retencion_requiere_motivo_o_notas` exige justamente lo que la
    # limpieza borraría.
    paquete = Paquete.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                              tracking: "1ZESTADORETENIDO1", descripcion: "x",
                              estado: "recibido_miami", user: users(:admin),
                              sucursal_recepcion: sucursales(:miami),
                              retener_miami: true, motivo_retencion_ids: @motivos.map(&:id))
    paquete.update!(estado: "retenido")

    paquete.update!(retener_miami: false)

    assert_equal @motivos.size, paquete.reload.motivo_retencion_ids.size
  end

  private

  def crear_con_retencion(motivos:, notas:)
    pa = PreAlerta.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                           titulo: "Con retención", estado: "pre_alerta")
    pa.pre_alerta_paquetes.create!(tracking: "1ZRET#{SecureRandom.hex(5).upcase}",
                                   descripcion: "Lo que viene", retener_miami: true,
                                   motivo_retencion_ids: motivos, notas_retencion: notas)
    pa
  end
end
