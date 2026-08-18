require "test_helper"

# PR-C6.43: el guardado del editor de admin devolvía la respuesta equivocada, y
# eso **duplicaba paquetes**.
#
# `PreAlertasController#update` respondía `{ ok: true }`, sin `new_paquetes`. El
# editor hace `_injectNewPaqueteIds(data.new_paquetes || {})`, así que el bucle
# no corría nunca y la fila recién creada se quedaba **sin su `id` oculto**. Al
# segundo F8 se reenviaba como si fuera nueva, y
# `accepts_nested_attributes_for` creaba un segundo registro — que por
# `crear_paquete_esperado` mete un segundo Paquete en bodega.
#
# F8 es la única forma de guardar en esa pantalla. El segundo apretón no es un
# caso raro: es lo que hace cualquiera que agrega un paquete, sigue escribiendo
# y vuelve a guardar.
#
# El portal del cliente nunca lo tuvo porque su `update` devuelve `new_paquetes`
# desde el principio. Es la misma pantalla, escrita dos veces.
class PreAlertasAutosaveTest < ActionDispatch::IntegrationTest
  setup do
    post session_url, params: { email_address: users(:admin).email_address, password: "password123" }
    # Consolidada: agregarle paquetes es justo lo que esta pantalla hace, y
    # sin consolidar la regla nueva lo bloquea (que es lo que Yusef pidió).
    @pa = pre_alertas(:consolidada_destino)
  end

  test "guardar dos veces no duplica el paquete" do
    antes = @pa.pre_alerta_paquetes.count

    # Primer F8: la fila es nueva, sin `id`.
    guardar(nuevo_paquete("1Z999AUTOSAVE1"))
    assert_response :success

    ids = JSON.parse(response.body)["new_paquetes"]
    assert_equal [ "0" ], ids.keys, "no devolvió el id de la fila nueva"
    id_asignado = ids["0"]

    # Segundo F8: la fila ya tiene su id, así que se actualiza en vez de nacer
    # otra vez. Ese `id` es justo lo que el JS acaba de inyectar.
    guardar({ "0" => { id: id_asignado, tracking: "1Z999AUTOSAVE1", descripcion: "Zapatos" } })
    assert_response :success

    assert_equal antes + 1, @pa.reload.pre_alerta_paquetes.count,
                 "el segundo guardado creó el paquete otra vez"
    assert_equal 1, PreAlertaPaquete.where(pre_alerta: @pa, tracking: "1Z999AUTOSAVE1").count
  end

  test "no duplica el paquete esperado en bodega" do
    # El daño real no es la fila: es que cada PreAlertaPaquete materializa un
    # Paquete, así que el duplicado aparece en /paquetes como si hubieran
    # llegado dos cajas.
    guardar(nuevo_paquete("1Z999AUTOSAVE2"))
    id_asignado = JSON.parse(response.body)["new_paquetes"]["0"]

    guardar({ "0" => { id: id_asignado, tracking: "1Z999AUTOSAVE2", descripcion: "Zapatos" } })

    assert_equal 1, Paquete.where(tracking: "1Z999AUTOSAVE2").count
  end

  test "el error viaja bajo la llave que el JS lee" do
    # El JS hace `Array.isArray(data.errors)`. Con `errores` el operario veía
    # "Error al guardar" genérico en vez de saber cuál tracking está repetido.
    existente = @pa.pre_alerta_paquetes.first

    guardar({ "0" => { tracking: existente.tracking, descripcion: "Repetido" } })

    assert_response :unprocessable_entity
    cuerpo = JSON.parse(response.body)
    assert_equal "error", cuerpo["status"]
    assert cuerpo["errors"].is_a?(Array) && cuerpo["errors"].any?,
           "el editor no puede mostrar un error que viene bajo otra llave"
  end

  test "una fila marcada para borrar no cuenta como nueva" do
    # Defensa en profundidad: la pantalla de hoy no produce este estado —una
    # fila nueva que se borra sale del DOM entera, sin `_destroy`— pero la
    # búsqueda es por TRACKING, y sin el guard una fila marcada para borrar
    # matchearía contra el paquete que ya existe. El JS le inyectaría el `id`
    # de ese registro a una fila que el usuario acaba de eliminar, y el
    # siguiente guardado la resucitaría.
    existente = @pa.pre_alerta_paquetes.first

    guardar({ "0" => { tracking: existente.tracking, descripcion: existente.descripcion, _destroy: "1" } })

    assert_response :success
    assert_empty JSON.parse(response.body)["new_paquetes"],
                 "le devolvió un id a una fila marcada para borrar"
  end

  test "el PATCH json sin autosave sigue respondiendo como antes" do
    # PR-C6.25 dejó esa rama y hay tests que la usan. No se toca.
    patch pre_alerta_url(@pa, format: :json), params: { pre_alerta: { titulo: "Otro titulo" } }

    assert_response :success
    assert_equal true, JSON.parse(response.body)["ok"]
  end

  private

  def nuevo_paquete(tracking)
    { "0" => { tracking: tracking, descripcion: "Zapatos" } }
  end

  def guardar(paquetes_attributes)
    patch pre_alerta_url(@pa), params: {
      autosave: "true",
      pre_alerta: { pre_alerta_paquetes_attributes: paquetes_attributes }
    }, as: :json
  end
end
