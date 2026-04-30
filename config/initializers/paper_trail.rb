# PR-D1.a: configura paper_trail para que `changeset` funcione bien con
# columnas de fechas/timestamps. El YAML serializer default usa
# `Psych.safe_load` que en Rails 7+ rechaza Date/Time/Symbol por default,
# devolviendo `{}` desde `version.changeset`.
#
# Solución: permitir las clases que usamos en columnas comunes.
PaperTrail.config.version_limit = 100  # mantén las últimas 100 versions por record

# Permitir clases necesarias en YAML safe_load.
ActiveRecord.yaml_column_permitted_classes = [
  Symbol,
  Date,
  Time,
  DateTime,
  ActiveSupport::TimeWithZone,
  ActiveSupport::TimeZone,
  BigDecimal
]
