# PR-D1.a: configura paper_trail para que `changeset` funcione bien con
# columnas de fechas/timestamps. El YAML serializer default usa
# `Psych.safe_load` que en Rails 7+ rechaza Date/Time/Symbol por default,
# devolviendo `{}` desde `version.changeset`.
#
# Solución: permitir las clases que usamos en columnas comunes.
# Mantén solo las últimas 100 versions por record. paper_trail purga
# automáticamente las más viejas cuando se supera el límite. Razones:
#   - Evita crecimiento descontrolado de la tabla `versions` (un paquete
#     muy editado puede acumular cientos de versions sin valor).
#   - Acota el tamaño de la respuesta JSON cuando exponemos la bitácora.
#   - Si en el futuro se necesitan logs forenses más profundos, mejor
#     mover a un sistema dedicado (ej. CloudWatch, Datadog) que mantener
#     historia completa en la BD operativa.
# Trade-off conocido: cambios muy antiguos se pierden. Aceptable para el
# scope actual del audit log (revisión operativa, no compliance forense).
PaperTrail.config.version_limit = 100

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
