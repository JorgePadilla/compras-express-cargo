# C24-01 · Una excepción de cobro que vive en el paquete, no en el cliente.
#
# Yusef, 2026-09-05, sobre unos generadores de 400 lb reales y 150 volumétricas:
# *"es lo que yo voy a cobrar"* — el **menor** de los dos, al revés de la regla
# normal. Y acotó el alcance él mismo: *"el cliente **no es que toda la carga**
# ya se la cobro por peso, **sino que exclusivamente esa**"*.
#
# Por eso no sirve `ClienteCobroVolumetrico` (`PR-C6.41`), que es por cliente ×
# tipo de envío: prenderlo le cambiaría el cobro a toda su carga.
#
# **Va como texto y no como booleano** porque él nombró **tres** clases —*"tanto
# por libras, tanto por volumen o tanto…"*— y solo «por volumen» tiene caso
# concreto. Las otras dos son `RP-62`, pendientes de que las defina; con una
# columna de texto entran después **sin migración**.
#
# El índice es **parcial**: son unos pocos paquetes contra una tabla que crece
# con toda la carga del año.
class CobroExcepcionPorPaquete < ActiveRecord::Migration[8.0]
  def change
    add_column :paquetes, :cobro_excepcion, :string

    add_index :paquetes, :cobro_excepcion,
              where: "cobro_excepcion IS NOT NULL",
              name: "index_paquetes_on_cobro_excepcion"
  end
end
