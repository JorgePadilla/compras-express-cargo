# C21-02 · C21-03 · C21-11 — el encabezado que Yusef anotó a mano.
#
# Las anotaciones sobre el manifiesto impreso del legacy dicen, campo por campo,
# **quién llena qué**: consignatario, tipo de envío del proveedor y «es
# prioridad» los pone Miami; el número de guía y la fecha de aduana los pone
# después la encargada de operaciones en San Pedro Sula.
#
# Lo que falta en la tabla y entra acá:
#
#   · **consignatario** — a quién va la carga. *"Corporación Karsam."*
#   · **tipo de envío del proveedor** — el suyo, no el nuestro. Hasta hoy este
#     campo era un varchar que el formulario llenaba con NUESTRO catálogo.
#   · **sucursal de entrega** — *"le va a preguntar sucursal, ¿sucursal a
#     entregar?… ahorita tenemos Tegu[cigalpa], SPS"*. El manifiesto no la tenía.
#   · **es prioridad** — el checkbox que ya existe en el impreso.
#   · **los tipos de envío NUESTROS**, en selección múltiple: *"aquí es selección
#     múltiple… podés seleccionar todos los cinco tipos de servicio que tengo
#     actuales. ¿Por qué seleccionás todo? Porque a veces combinás todo y lo
#     mandás"*. Con la regla: *"no puede ser sin ninguno, tiene que llevar uno
#     mínimo"*.
#   · **las guías, en plural**: *"el número de guía termina siendo varios"* —
#     `286441-1`, `-2`, `-3`, que él mismo comparó con nuestros splits: *"es el
#     mismo número, solo tiene el 1, el 2 y el 3; es el mismo que nosotros, la
#     misma teoría"*.
#
# Las columnas viejas `tipo_envio`, `numero_guia` y `numero_caja` **no se
# borran**: dejan de escribirse y quedan para leer lo que ya está grabado.
class ManifiestoEncabezadoYNumeracion < ActiveRecord::Migration[8.0]
  def up
    change_table :manifiestos, bulk: true do |t|
      t.references :consignatario, foreign_key: true
      t.references :tipo_envio_proveedor, foreign_key: true
      t.references :sucursal_entrega, foreign_key: { to_table: :sucursales }
      t.boolean :es_prioridad, null: false, default: false
    end

    create_table :manifiesto_tipo_envios do |t|
      t.references :manifiesto, null: false, foreign_key: true
      t.references :tipo_envio,  null: false, foreign_key: true
      t.timestamps
    end
    add_index :manifiesto_tipo_envios, %i[manifiesto_id tipo_envio_id], unique: true

    create_table :manifiesto_guias do |t|
      t.references :manifiesto, null: false, foreign_key: true
      t.string  :numero, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :manifiesto_guias, %i[manifiesto_id numero], unique: true

    # Los manifiestos con el formato legacy `MA-…`. Decisión de Jorge
    # (2026-08-30): **borrarlos**. Son de prueba —en dev había dos—, no hay
    # producción todavía, y la numeración anual arranca limpia. Los paquetes que
    # los apuntaran quedan sueltos, que es lo mismo que hace `dependent: :nullify`.
    execute "UPDATE paquetes SET manifiesto_id = NULL WHERE manifiesto_id IN (SELECT id FROM manifiestos WHERE numero LIKE 'MA-%')"
    execute "DELETE FROM manifiestos WHERE numero LIKE 'MA-%'"
  end

  def down
    drop_table :manifiesto_guias
    drop_table :manifiesto_tipo_envios
    change_table :manifiestos, bulk: true do |t|
      t.remove :consignatario_id, :tipo_envio_proveedor_id, :sucursal_entrega_id, :es_prioridad
    end
  end
end
