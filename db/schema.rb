# ⚠️ ESTE ARCHIVO NO SE USA. La verdad está en `db/structure.sql`.
#
# El repo corre con `config.active_record.schema_format = :sql`
# (`config/application.rb`), así que Rails no lee ni regenera esto: quedó
# congelado en algún punto de 2026 y desde entonces miente.
#
# C20-10 lo descubrió del peor modo: un diagnóstico de performance se hizo
# leyendo acá, concluyó que faltaban índices que en realidad existían hace
# meses en `structure.sql`, y estuvo a punto de agregarlos por segunda vez.
#
# Se deja este archivo —y no se borra— para que quien lo abra por costumbre
# lea esto en vez del contenido viejo.
