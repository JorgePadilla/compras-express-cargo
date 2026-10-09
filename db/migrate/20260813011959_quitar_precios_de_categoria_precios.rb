class QuitarPreciosDeCategoriaPrecios < ActiveRecord::Migration[8.0]
  # Una categoría agrupa clientes; los precios viven en `tarifas`.
  #
  # Yusef: *"la categoría de precio confunde con la tabla de servicios, y está en
  # lempiras la de categoría y el Excel está en dólares"*. Las dos cosas eran
  # ciertas, y la segunda era peor de lo que suena: **no había columna `moneda`**.
  # Las vistas rotulaban "(LPS/lb)" y ponían `L.` adelante, pero los números
  # estaban de facto en dólares — el backfill de `create_tarifas.rb:100` los copió
  # a `tarifas` estampándoles `'USD'`, y las magnitudes solo cierran así: 3.50
  # contra un precio de lista de $4.50 es coherente; leído como lempiras a 27.10
  # sería $0.13/lb de flete aéreo.
  #
  # Desde `PR-C7.06` ningún cálculo las leía. Se van de la base y no solo de la
  # pantalla porque mientras existan alguien las va a volver a editar creyendo
  # que sirven.
  #
  # Los valores que tenían ya están donde importan: el backfill los copió a
  # `tarifas` en 2026-08, y de ahí en adelante el historial lo lleva PaperTrail.
  def up
    remove_column :categoria_precios, :precio_libra_aereo
    remove_column :categoria_precios, :precio_libra_maritimo
    remove_column :categoria_precios, :precio_volumen
  end

  # Se puede revertir la forma de la tabla, pero no los números: vuelven en nil.
  # Está a propósito — restaurarlos con un valor inventado sería peor.
  def down
    add_column :categoria_precios, :precio_libra_aereo,    :decimal, precision: 10, scale: 2
    add_column :categoria_precios, :precio_libra_maritimo, :decimal, precision: 10, scale: 2
    add_column :categoria_precios, :precio_volumen,        :decimal, precision: 10, scale: 2
  end
end
