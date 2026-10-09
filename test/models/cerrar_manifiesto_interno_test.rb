require "test_helper"

# `A7-09` · Cerrar el manifiesto **interno** manda su carga a `enviado_sucursal`.
#
# Yusef pidió ese estado como F7, y dijo para qué sirve:
#
#   > "¿Por qué va a servir ese status nuevo? **Porque esto sirve de auditoría.**
#    Qué paquete no escanearon o no enviaron… se pueden ir a revisar el sistema y
#    decir: ey, este sale pendiente, hay que buscarlo."
#   > "A qué me refiero: que **los errores se corrijan en 24 horas**."
#
# El estado existía en el enum **sin un solo escritor** desde que se agregó.
# Éste es el primero.
#
# Y no notifica nada, a propósito: *"solo en sistema va a cambiar el estatus"*.
# Al cliente se le avisa cuando la carga **llega**, no cuando sale.
class CerrarManifiestoInternoTest < ActiveSupport::TestCase
  def interno(**attrs)
    Manifiesto.create!(
      tipo: "interno",
      sucursal_origen: sucursales(:zeron_sps),
      sucursal_entrega: sucursales(:humuya_tgu),
      tipo_envios: [ tipo_envios(:cer) ],
      **attrs
    )
  end

  def oficial(**attrs)
    Manifiesto.create!(sucursal_origen: sucursales(:miami),
                       tipo_envios: [ tipo_envios(:cer) ], **attrs)
  end

  def paquete_en(manifiesto, **attrs)
    Paquete.create!(
      tracking: "1Z#{SecureRandom.hex(5).upcase}",
      cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
      sucursal_recepcion: sucursales(:miami), sucursal: sucursales(:zeron_sps),
      estado: "disponible_entrega", descripcion: "Perfumes", peso: 5,
      user: users(:digitador), manifiesto: manifiesto, **attrs
    )
  end

  # ── Lo que cambia según el tipo ─────────────────────────────────────────

  test "el interno manda a enviado_sucursal, el oficial a enviado_honduras" do
    m_int = interno
    p_int = paquete_en(m_int)
    m_int.finalizar!(user: users(:supervisor_miami))

    assert_equal "enviado_sucursal", p_int.reload.estado

    m_of = oficial
    p_of = paquete_en(m_of)
    m_of.finalizar!(user: users(:supervisor_miami))

    assert_equal "enviado_honduras", p_of.reload.estado,
                 "el oficial no se movió de donde estaba"
  end

  # El destino sale del manifiesto y no del cliente. `heredar_sucursal_destino`
  # cae a la sucursal donde el cliente retira —el caso normal—, pero el
  # manifiesto sabe a dónde va el camión de verdad.
  test "el destino sale del manifiesto, no de dónde retira el cliente" do
    m = interno
    # El cliente retira en SPS; el manifiesto va a Tegucigalpa.
    p = paquete_en(m, sucursal: sucursales(:zeron_sps))

    m.finalizar!(user: users(:supervisor_miami))

    assert_equal sucursales(:humuya_tgu), p.reload.sucursal_destino,
                 "se marcó como que va a SPS, que es de donde está saliendo"
  end

  test "estampa la fecha y quién la disparó, en la columna del estado correcto" do
    m = interno
    p = paquete_en(m)

    m.finalizar!(user: users(:supervisor_miami))
    p.reload

    assert p.fecha_enviado_sucursal.present?
    assert_equal users(:supervisor_miami).id, p.fecha_enviado_sucursal_by_user_id
  end

  # ── La guarda de tareas ─────────────────────────────────────────────────
  #
  # El caso que el modelo **no** cubre: `no_advance_with_open_tareas` compara
  # índices de `ESTADOS_ORDEN`, y `enviado_sucursal` no está ahí porque es un
  # desvío. Sin preguntarlo en el servicio, el interno se cerraría con paquetes
  # que tienen algo pendiente — justo lo que Jorge decidió que trabara el cierre.

  test "una tarea abierta traba el cierre del interno, igual que el del oficial" do
    m = interno
    p = paquete_en(m)
    Tarea.create!(titulo: "Falta la factura comercial", paquete: p,
                  cliente: p.cliente, bloquea_avance: true, estado: "pendiente",
                  origen: "manual")

    resultado = m.finalizar!(user: users(:supervisor_miami))

    assert resultado.bloqueado?, "se cerró con un paquete que tenía algo pendiente"
    assert_equal "disponible_entrega", p.reload.estado, "y el paquete no se movió"
    assert_equal "creado", m.reload.estado, "ni el manifiesto"
  end

  test "sin tareas abiertas sí cierra" do
    m = interno
    paquete_en(m)

    resultado = m.finalizar!(user: users(:supervisor_miami))

    assert_not resultado.bloqueado?
    assert_equal 1, resultado.enviados.size
    assert_equal "enviado", m.reload.estado
  end

  # ── Lo que NO hace ──────────────────────────────────────────────────────

  test "cerrar el interno no le manda ningún correo al cliente" do
    m = interno
    paquete_en(m)

    assert_no_difference "ActionMailer::Base.deliveries.size" do
      m.finalizar!(user: users(:supervisor_miami))
    end
  end
end
