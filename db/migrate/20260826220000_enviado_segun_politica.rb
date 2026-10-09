# «Enviado según política de envío» — la listita como la de retener.
#
# Yusef, 2026-08-26 (`C18-06`): *"hay una cuestión que le queríamos agregar…
# es lo mismo que vos tenés como cuando retenés. Como una nota de por qué se le
# envió [así]. El paquete no llegó identificado con tipo de envío; antes nos
# poníamos a preguntarle a la gente qué tipo de envío quiere, ahora los
# enviamos nosotros de acuerdo a las políticas. Necesitamos una listita igual
# como la otra: se le marca el checkbox y te despliega."* Unos 100 paquetes al
# mes: sin pre-alerta, etiqueta incompleta, nombre a medias, desconocido.
#
# Mismo esqueleto que la retención (`20260430052744`): catálogo administrable
# + join + bandera y texto libre en el paquete. `texto_al_cliente` es la frase
# que se compone en `paquetes.notas_al_cliente` y viaja en el correo de
# recibido — es una explicación al cliente, no una nota interna.
class EnviadoSegunPolitica < ActiveRecord::Migration[8.0]
  def change
    create_table :motivos_envio_politica do |t|
      t.string  :nombre,           null: false
      t.text    :texto_al_cliente, null: false
      t.integer :position,         null: false, default: 0
      t.boolean :activo,           null: false, default: true
      t.timestamps
    end
    add_index :motivos_envio_politica, :nombre, unique: true
    add_index :motivos_envio_politica, :activo

    create_table :paquete_motivos_envio_politica do |t|
      t.references :paquete, null: false, foreign_key: { on_delete: :cascade }
      t.references :motivo_envio_politica, null: false,
                   foreign_key: { to_table: :motivos_envio_politica, on_delete: :restrict }
      t.timestamps
    end
    add_index :paquete_motivos_envio_politica, [ :paquete_id, :motivo_envio_politica_id ], unique: true,
              name: "idx_paquete_motivos_envio_politica_pair"

    add_column :paquetes, :enviado_por_politica, :boolean, null: false, default: false
    add_column :paquetes, :notas_envio_politica, :text
  end
end
