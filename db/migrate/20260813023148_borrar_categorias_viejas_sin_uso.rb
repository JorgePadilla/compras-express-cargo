class BorrarCategoriasViejasSinUso < ActiveRecord::Migration[8.0]
  # Saca las categorías de la época vieja que ya no usa nadie.
  #
  # Jorge preguntó si se podía eliminar "categorías de precios" porque después de
  # `PR-C7.08` parecía no tener sentido. La tabla se queda —es el nivel 3 de la
  # cascada y sirve 28 de las 44 tarifas— pero tenía razón en lo literal: **no
  # había forma de borrar una categoría**, y Regular y VIP quedaron vacías cuando
  # sus clientes se movieron.
  #
  # La regla no es "borrar Regular y VIP" a mano sino la que se puede defender:
  # **vacía y no declarada en la hoja de precios de Yusef**. Así, si mañana
  # aparece otro vestigio se limpia solo, y Familia/Revendedores —vacías pero
  # declaradas a propósito, sus clientes caen a lista— no se tocan.
  def up
    unless defined?(TarifasPropuesta2026)
      say "TarifasPropuesta2026 no está disponible; no se toca nada."
      return
    end

    declaradas = TarifasPropuesta2026::CATEGORIAS.map { |c| c[:nombre] }

    sobrantes = CategoriaPrecio.where.not(nombre: declaradas).select do |c|
      Cliente.where(categoria_precio_id: c.id).none? &&
        Tarifa.where(categoria_precio_id: c.id).none?
    end

    if sobrantes.empty?
      say "No hay categorías vacías fuera de la hoja de precios."
      return
    end

    # Sin esto el audit log guarda el borrado sin autor: la migración no corre
    # con un usuario logueado.
    PaperTrail.request.whodunnit = "migracion 20260813023148"

    sobrantes.each do |c|
      say "borrando \"#{c.nombre}\": sin clientes, sin tarifas, y la hoja no la declara"
      c.destroy!
    end

    say "#{sobrantes.size} categoría(s) borrada(s)."
  ensure
    PaperTrail.request.whodunnit = nil
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Las categorías borradas estaban vacías; recrearlas a ciegas les inventaría un nombre. " \
          "Quedaron en las versiones de PaperTrail."
  end
end
