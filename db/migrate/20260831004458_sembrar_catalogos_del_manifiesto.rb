# C21-08 · Sembrar los catálogos del manifiesto donde el deploy no siembra.
#
# `PR-M1` estrenó tres catálogos —tipo de envío del proveedor, consignatarios y
# tamaños de caja— y `PR-M10` les puso semilla en `db/seeds.rb`. En dev quedaron
# cargados; en staging siguieron **vacíos**, porque el deploy solo migra:
#
#   render.yaml → preDeployCommand: bundle exec rails db:migrate
#
# Jorge, 2026-08-30: *"nos faltaron los seeds de los catálogos, solo empresas
# proveedoras tenemos, los otros 3 están vacíos… agreguemos migración si es
# necesario"*. Sí hacía falta: una migración de datos es lo único que corre solo
# en cada deploy.
#
# Empresas de manifiesto es el único que sí tiene datos allá, porque se sembró
# en el arranque del proyecto — de ahí que sea justo el que no falta.
#
# La lista vive en `lib/catalogos_del_manifiesto.rb` y no acá adentro: tenerla
# dos veces —en la migración y en los seeds— es cómo se separan. El precio es
# que esta migración depende de un archivo de `lib/`; se asume, porque el
# esquema de este repo es `structure.sql` y una instalación nueva carga el
# esquema en vez de correr las migraciones desde cero.
class SembrarCatalogosDelManifiesto < ActiveRecord::Migration[8.0]
  def up
    require Rails.root.join("lib/catalogos_del_manifiesto")
    creados = CatalogosDelManifiesto.sembrar!
    say "catálogos sembrados: #{creados.map { |k, v| "#{v} #{k}" }.join(', ')}" if creados.any?
  end

  # Irreversible a propósito: bajar esta migración borraría catálogos que el
  # equipo puede haber estado usando —y a los que ya cuelgan manifiestos—, no
  # solo las filas que creó. Deshacerla es sacar los registros a mano.
  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
