# C30-06 · El manifiesto finalizado se abre con «Editar», y queda anotado.
#
# Yusef: *"que le demos un botón que diga editar… y entonces ya podemos editar
# todo, otra vez… pero que presionen el botón, para que nadie toque algo que no
# era. Ya nos pasó de que venían y sin querer tocaban el manifiesto que ya se
# había ido"*.
#
# Dos columnas y no un permiso por pedido: el botón se aprieta **una vez** y
# después se escanea muchas, y quien abra la ficha mientras tanto tiene que ver
# que está abierto y por quién. paper_trail guarda quién lo abrió y quién lo
# cerró. Misma forma que `finalizado_por` / `finalizado_at`.
class EdicionAbiertaDelManifiesto < ActiveRecord::Migration[8.0]
  def change
    change_table :manifiestos, bulk: true do |t|
      t.references :edicion_abierta_por, foreign_key: { to_table: :users }
      t.datetime :edicion_abierta_at
    end
  end
end
