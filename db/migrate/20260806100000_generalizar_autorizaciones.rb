# PR-13.e: la autorización deja de ser solo de líneas de pre-factura.
#
# Yusef confirmó que en las notas de débito y crédito el control va en otro
# lado: la nota no saca su monto de la tabla de tarifas —su propósito es
# ajustar a mano—, así que trabar cada línea sería trabar justamente lo que el
# documento viene a hacer. El control va **al emitir**, que es el momento en que
# el saldo del cliente cambia.
#
# Es el mismo hecho de negocio que el de la pre-factura ("un supervisor autorizó
# esto con su PIN"), así que va en la misma tabla y en la misma bitácora: si no,
# habría dos lugares donde mirar cuánta plata se movió sin tarifa detrás.
#
# `documento` polimórfico porque los tres —PreFactura, NotaCredito y
# NotaDebito— responden a `numero` y `cliente`, que es todo lo que la bitácora
# necesita para mostrarlos juntos.
class GeneralizarAutorizaciones < ActiveRecord::Migration[8.0]
  def up
    rename_table :autorizaciones_linea, :autorizaciones

    add_column :autorizaciones, :documento_type, :string
    add_column :autorizaciones, :documento_id, :bigint

    execute <<~SQL
      UPDATE autorizaciones
         SET documento_type = 'PreFactura',
             documento_id   = pre_factura_id
    SQL

    change_column_null :autorizaciones, :documento_type, false
    change_column_null :autorizaciones, :documento_id, false
    add_index :autorizaciones, [ :documento_type, :documento_id ]

    remove_reference :autorizaciones, :pre_factura, foreign_key: true
  end

  def down
    add_reference :autorizaciones, :pre_factura, foreign_key: true

    execute <<~SQL
      UPDATE autorizaciones
         SET pre_factura_id = documento_id
       WHERE documento_type = 'PreFactura'
    SQL

    # Las autorizaciones de notas no tienen dónde volver.
    execute "DELETE FROM autorizaciones WHERE documento_type <> 'PreFactura'"
    change_column_null :autorizaciones, :pre_factura_id, false

    remove_index :autorizaciones, [ :documento_type, :documento_id ]
    remove_column :autorizaciones, :documento_type
    remove_column :autorizaciones, :documento_id

    rename_table :autorizaciones, :autorizaciones_linea
  end
end
