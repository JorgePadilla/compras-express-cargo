require "test_helper"

# PR-C6.38: de dónde vino el paquete — Estados Unidos, China, Panamá.
#
# Yusef, sobre el campo que el sistema viejo tenía marcado en pantalla:
#
#   "Lo que marca acá, si es de China no sé qué. Eso es algo que tenemos que
#    ver… como ahorita estamos en Estados Unidos, pero **ya va a abrir China**."
#
# Quedó como pregunta abierta (`A1-25`) porque parecía que había que definir un
# campo nuevo. Revisando el modelo: **`Paquete` no tiene ninguna columna de
# origen** — ese campo era del sistema viejo. Y `Sucursal` **ya tiene `pais`**.
#
# El origen es el país de la sucursal donde se **recibió**, y esa ya se elige
# al abrir la sesión de etiquetado — Yusef mismo lo describió así: "está
# alguien en Miami recibiendo, o en Panamá, o en China".
#
# Así que no se agrega columna. El día que abran China crean su sucursal y esto
# funciona solo, sin que nadie tenga que acordarse de marcar un campo más — que
# es exactamente el tipo de error que este proyecto viene arrastrando.
class PaqueteOrigenTest < ActiveSupport::TestCase
  test "un paquete recibido en Miami viene de Estados Unidos" do
    paquete = paquetes(:recibido)
    paquete.update!(sucursal_recepcion: sucursales(:miami))

    assert_equal "USA", paquete.origen
  end

  test "cuando abran China el origen sale solo" do
    # Sin tocar código ni migrar nada: se crea la sucursal y listo.
    # `ubicacion` es una lista corta (`miami`, `honduras`, `otros`) que agrupa
    # para permisos; el país es texto libre. Así que un origen nuevo se
    # representa hoy, sin migrar ni ampliar nada.
    china = Sucursal.create!(codigo: "PVG", nombre: "Shanghai", pais: "China",
                             ubicacion: "otros", codigo_recepcion_prefix: "RSH")
    paquete = paquetes(:recibido)
    paquete.update!(sucursal_recepcion: china)

    assert_equal "China", paquete.origen
  end

  test "sin sucursal de recepcion cae a la de retiro" do
    # Mismo fallback que `sucursal_del_numero`, del que sale el número de
    # recepción. Son la misma pregunta: ¿dónde entró este paquete al sistema?
    paquete = paquetes(:recibido)
    paquete.update_columns(sucursal_recepcion_id: nil, sucursal_id: sucursales(:humuya_tgu).id)

    assert_equal "Honduras", paquete.reload.origen
  end

  test "un paquete sin ninguna sucursal no inventa un origen" do
    paquete = paquetes(:recibido)
    paquete.update_columns(sucursal_recepcion_id: nil, sucursal_id: nil)

    assert_nil paquete.reload.origen
  end
end
