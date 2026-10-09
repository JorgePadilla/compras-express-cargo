# C21-04 · Las casas del manifiesto — la entidad que faltaba.
#
# Todo lo que Yusef especificó cuelga de acá: la etiqueta 4×6 del bulto, el
# escaneo al empacar, y el escaneo al recibir en Honduras. `docs/06` lo tenía
# anotado desde la Conversación 5, en una línea que quedó sin cumplir por meses:
# *"Falta la entidad de «caja empacada» entre `Paquete` y `Manifiesto`."*
#
# **El paquete conserva `manifiesto_id` y gana `caja_manifiesto_id`, los dos
# opcionales.** No se llega al manifiesto «a través de» la caja, y la razón la
# dio Yusef mismo: los dos caminos se mantienen —con escaneo y sin escaneo,
# *"porque a veces no da tiempo"*—, así que un paquete metido al manifiesto por
# el camino viejo tiene que ser expresable **sin ninguna caja**. Además todo lo
# que ya existe cuelga de `paquete.manifiesto_id`: el scope `sin_manifiesto`, el
# `sync_dates_from_manifiesto`, la limpieza de retroceso y el autocomplete.
#
# **El código de la caja es `<número del manifiesto>-<letra>`**, guardado y con
# índice único. No hace falta un contador nuevo: es único por construcción y
# reusa la convención de sufijos que Yusef ratificó él mismo hablando de las
# guías del proveedor (`286441-1/-2/-3`): *"es el mismo número, solo tiene el 1,
# el 2 y el 3. Es el mismo que nosotros, **la misma teoría**"*. Es también la
# forma que ya tiene `etiqueta_codigo_barras` para las cajas de un split.
#
# **`ultima_letra` es un marcador que solo sube.** Si la letra saliera de un
# `MAX` sobre las filas vivas, borrar la última caja después de imprimir su
# etiqueta y agregar otra reusaría la letra — y quedaría una etiqueta física,
# ya pegada a un bulto, apuntando a otra caja.
class CajasDelManifiesto < ActiveRecord::Migration[8.0]
  def change
    create_table :caja_manifiestos do |t|
      t.references :manifiesto,  null: false, foreign_key: true
      t.references :tamano_caja, foreign_key: true   # nulo = «Especificar»
      t.references :user,        foreign_key: true
      t.string  :letra,  null: false
      t.string  :codigo, null: false
      # El `DM7155` del sistema viejo. Se muestra; el que se escanea es `codigo`.
      t.string  :numero_doc
      # Se copian del tamaño y **quedan editables**: *"ellos vienen y marcan EH
      # y le modifican una medida, porque la cortan… le decimos «EH cortada»"*.
      t.decimal :alto,  precision: 8, scale: 2
      t.decimal :largo, precision: 8, scale: 2
      t.decimal :ancho, precision: 8, scale: 2
      t.decimal :peso,    precision: 10, scale: 2
      t.decimal :volumen, precision: 10, scale: 2
      t.timestamps
    end
    add_index :caja_manifiestos, :codigo, unique: true
    add_index :caja_manifiestos, %i[manifiesto_id letra], unique: true

    add_reference :paquetes, :caja_manifiesto, foreign_key: true

    change_table :manifiestos, bulk: true do |t|
      t.integer :cantidad_bultos, null: false, default: 0
      # Marcador que solo sube. Ver el comentario de arriba.
      t.integer :ultima_letra, null: false, default: 0
    end
  end
end
