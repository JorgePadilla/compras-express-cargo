# C26-19 · El bulto: la unidad que se mide y que lleva la etiqueta.
#
# Hasta acá el módulo asumía **una medición por caja**. Yusef, el 2026-09-07,
# viendo por cámara cómo trabaja el operario, lo corrigió tres veces y textual:
#
#   "**No es una etiqueta por paquete, es una etiqueta por medición**, y la
#    medición puede tener 100 paquetes."
#
# El operario junta cajas en la mesa hasta que le cuadran —*"le voy a sacar tres
# volúmenes, así lo dicen ellos, porque son diferentes de tamaño"*— y mide el
# bulto entero. La razón es de plata: *"si yo mido esto [caja por caja], te estoy
# cobrando espacio vacío"*.
#
# ── Por qué una tabla y no cuatro columnas más en `paquetes` ───────────────
#
# Porque el bulto es la **unidad de cobro**, y el paquete no puede serlo dos
# veces. `Paquete#calculate_peso_cobrar` es un `before_save` que recalcula desde
# los números **de cada paquete**: copiarle a las tres cajas de un bulto los
# mismos 20 lb le cobra 60 al cliente. Y repartir tampoco sirve —la cadena de
# cobro corre por caja (redondeo → escalón → mínimo), así que 20 entre 3 puede
# terminar cobrando tres mínimos—.
#
# Así que el bulto guarda **sus** números y **su** peso a cobrar, y a las cajas
# solo se les pone el `bulto_id` y el sello. Sus `peso, alto, largo, ancho`
# siguen siendo lo que digitó Miami, que es el dato de Miami.
#
# ── `orden` y `de_cuantos` ────────────────────────────────────────────────
#
# Las mediciones de una sesión se guardan **todas juntas** al imprimir, como las
# cajas de /etiquetar (`A7-21`: *"cuando menos acordás me salieron cuatro en vez
# de cinco"*), así que en ese momento ya se sabe cuántas son. El QR y la etiqueta
# dicen «1 de 2» sobre eso, y es lo que audita pre-factura: *"cuando ella escanea
# cualquiera de los QR le dice: ¡eh!, son dos"*.
class ElBultoDeMedicion < ActiveRecord::Migration[8.0]
  def change
    create_table :bultos do |t|
      t.references :cliente, null: false, foreign_key: true
      t.references :user, foreign_key: true

      t.decimal :peso,  precision: 10, scale: 2
      t.decimal :alto,  precision: 10, scale: 2
      t.decimal :largo, precision: 10, scale: 2
      t.decimal :ancho, precision: 10, scale: 2
      t.decimal :peso_volumetrico, precision: 10, scale: 2
      t.decimal :peso_cobrar,      precision: 10, scale: 2

      # La sesión de escaneo, para el «1 de 2» y para reimprimir el grupo.
      t.string  :sesion, null: false
      t.integer :orden,      null: false, default: 1
      t.integer :de_cuantos, null: false, default: 1

      t.datetime :medido_at, null: false
      t.string   :medido_por

      t.timestamps
    end

    add_index :bultos, :sesion
    add_index :bultos, [ :sesion, :orden ], unique: true

    add_reference :paquetes, :bulto, foreign_key: true, index: true
  end
end
