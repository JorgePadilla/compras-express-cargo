# PR-F1.7 · Fase 15. Los RTN que ya estaban guardados, sin guiones ni espacios.
#
# Hasta PR-F1.1 el RTN de clientes y de la empresa era texto libre:
# «0801-1998-123456», «0801 1998 123456». Desde ahí `ConRtn` lo normaliza al
# guardar, pero solo lo que se vuelve a guardar; y como `normalizes` también
# reescribe las consultas, `Cliente.where(rtn: "08011998123456")` no encuentra
# al cliente viejo que lo tiene con guiones. Antes de facturar con el SAR, la
# búsqueda por RTN tiene que encontrarlos.
#
# La regla es la de `Fiscal.normalizar_rtn` —sacar espacios y guiones— y nada
# más:
#
# - **Nunca se inventa un dígito.** Solo se sacan separadores.
# - Solo se escribe si lo que queda son **14 dígitos**. Lo demás (letras, 13
#   dígitos, un RTN vacío) se queda **como está**: es dato real y corregirlo es
#   de quien conoce al cliente. La migración dice cuántos son, y
#   `bin/rails fiscal:rtn_invalidos` dice cuáles.
# - Idempotente: lo que ya son 14 dígitos no se toca, y correrla dos veces no
#   cambia nada la segunda.
#
# SQL directo y no los modelos: `Cliente` normaliza y valida, y una migración
# no debe depender de cómo esté el modelo el día que se corra (PR-F1.8). Por
# lo mismo no deja versión en paper_trail ni mueve `updated_at`: no es una
# edición de nadie, es el mismo dato escrito sin separadores.
class NormalizarRtnExistentes < ActiveRecord::Migration[8.0]
  TABLAS = %w[clientes empresas].freeze

  # Los mismos separadores que `Fiscal.normalizar_rtn` (`/[\s-]/` de Ruby):
  # espacio, tab, salto de línea, retorno, form feed, tab vertical y guion.
  SEPARADORES = "'[ \\t\\n\\r\\f\\v-]'"
  LIMPIO = "regexp_replace(rtn, E#{SEPARADORES}, '', 'g')".freeze
  CATORCE = "'^[0-9]{14}$'"

  def up
    TABLAS.each do |tabla|
      normalizados = connection.exec_update(<<~SQL.squish)
        UPDATE #{tabla} SET rtn = #{LIMPIO}
        WHERE rtn IS NOT NULL AND rtn !~ #{CATORCE} AND #{LIMPIO} ~ #{CATORCE}
      SQL
      fuera = connection.select_value(<<~SQL.squish).to_i
        SELECT COUNT(*) FROM #{tabla} WHERE rtn IS NOT NULL AND rtn <> '' AND rtn !~ #{CATORCE}
      SQL

      say "#{tabla}: #{normalizados} RTN normalizado#{"s" if normalizados != 1}; " \
          "#{fuera} siguen sin ser 14 dígitos (bin/rails fiscal:rtn_invalidos dice cuáles)"
    end
  end

  # No se deshace: los separadores no se guardaron en ningún lado, y volver a
  # ponerlos sería inventar un formato.
  def down; end
end
