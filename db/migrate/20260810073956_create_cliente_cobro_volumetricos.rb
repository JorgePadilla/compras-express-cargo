# PR-C6.41 · RP-04b: "cobrar solo volumen", por cliente y por tipo de envío.
#
# Yusef, al margen del cuestionario: *"hay clientes que solo se les cobra
# volumen en ciertos servicios; necesita quedar editable por cliente y por
# servicio"*. En el audio del 2026-08-08 lo amplió: son "mayoristas o clientes
# grandes", y la opción va "cuando creamos el cliente".
#
# **La presencia de la fila es el flag.** No hay columna booleana: si existe
# (cliente, tipo_envio), ese cliente paga solo volumétrico en ese servicio; sin
# fila, sigue el comportamiento de siempre —el mayor entre peso real y
# volumétrico—. Así no hay que sembrar una fila por cliente × servicio ni
# migrar nada cuando se agregue un tipo de envío nuevo.
class CreateClienteCobroVolumetricos < ActiveRecord::Migration[8.0]
  def change
    create_table :cliente_cobro_volumetricos do |t|
      t.references :cliente,    null: false, foreign_key: true
      t.references :tipo_envio, null: false, foreign_key: { to_table: :tipo_envios }

      t.timestamps
    end

    add_index :cliente_cobro_volumetricos, [ :cliente_id, :tipo_envio_id ],
              unique: true, name: "idx_cobro_volumetrico_cliente_tipo_envio"
  end
end
