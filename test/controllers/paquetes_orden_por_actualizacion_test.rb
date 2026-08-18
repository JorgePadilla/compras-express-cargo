require "test_helper"

# Yusef, 2026-08-18, con `/paquetes` en la pantalla compartida: las dos cajas de
# un mismo envío le salían **separadas** en el listado.
#
#   > "Lo único que no entiendo es por qué está separado, deberían de estar
#   >  juntitos. Porque eso puede ocasionar errores."
#
# La causa es de `PR-C7.20`: la Caja 1 **es** el paquete que la pre-alerta dejó
# esperando, así que conserva la hora en que el cliente lo anunció, mientras la
# Caja 2 nace al etiquetar. El listado ordenaba por `created_at`, y con media
# hora de diferencia quedaban en pantallas distintas.
#
#   > "Todas las actualizaciones tienen que ir con la última hora… si un paquete
#   >  está disponible en Honduras, se tiene que actualizar con la hora que se
#   >  marcó que estaba disponible."
class PaquetesOrdenPorActualizacionTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: {
      email_address: users(:admin).email_address, password: "password123"
    }
  end

  test "las cajas de un split reconciliado salen juntas" do
    viejo = crear("1Z999ORDEN000VIEJO", creado: 3.days.ago)
    cajas = crear_split("1Z999ORDEN000SPLIT")
    # La Caja 1 es la que nació antes, como pasa con un esperado reconciliado.
    cajas.first.update_columns(created_at: 5.days.ago)

    get paquetes_url

    posiciones = orden_en_la_pagina([ cajas.first.id, cajas.second.id, viejo.id ])
    assert_equal 1, (posiciones[cajas.first.id] - posiciones[cajas.second.id]).abs,
                 "las dos cajas del mismo envío salieron separadas"
  end

  test "lo que se acaba de tocar sube al tope" do
    crear("1Z999ORDEN000UNO")
    dos = crear("1Z999ORDEN000DOS")
    tres = crear("1Z999ORDEN000TRES")

    # Como marcar un paquete disponible en Honduras: se toca el más viejo.
    dos.update!(descripcion: "se le corrigió el contenido")

    get paquetes_url

    posiciones = orden_en_la_pagina([ dos.id, tres.id ])
    assert posiciones[dos.id] < posiciones[tres.id],
           "el que se acaba de tocar no subió"
  end

  test "el que ordena a mano sigue mandando" do
    get paquetes_url, params: { sort: "tracking", dir: "asc" }

    assert_response :success
  end

  test "la fecha de la primera columna lleva la hora" do
    paquete = crear("1Z999ORDEN000HORA")
    momento = paquete.fecha_recibido_miami || paquete.created_at

    get paquetes_url

    assert_response :success
    assert_includes response.body, momento.strftime("%H:%M")
  end

  private

  def crear(tracking, creado: nil)
    p = Paquete.create!(cliente: clientes(:juan), tipo_envio: tipo_envios(:cer),
                        tracking: tracking, descripcion: "x", estado: "recibido_miami",
                        user: users(:admin), sucursal_recepcion: sucursales(:miami))
    p.update_columns(created_at: creado) if creado
    p
  end

  def crear_split(tracking)
    Paquete.crear_split!(
      attrs: { cliente: clientes(:juan), tipo_envio: tipo_envios(:cer), tracking: tracking,
               descripcion: "Dos cajas", estado: "recibido_miami", user: users(:admin),
               sucursal_recepcion: sucursales(:miami) },
      total_cajas: 2, por_caja: { 1 => { peso: 12.5 }, 2 => { peso: 30 } }
    )
  end

  # En qué renglón sale cada paquete, por el orden en que aparece su enlace.
  def orden_en_la_pagina(ids)
    ids.index_with { |id| response.body.index(paquete_path(id)) || Float::INFINITY }
       .sort_by { |_id, pos| pos }
       .each_with_index.to_h { |(id, _pos), i| [ id, i ] }
  end
end
