require "test_helper"

# C21-06 · El candado del manifiesto finalizado, **aplicado**.
#
# `CAMPOS_DE_SAN_PEDRO` estaba declarado desde PR-M6 y **no lo usaba nadie**:
# un manifiesto cerrado aceptaba que le cambiaran cualquier campo de Miami,
# desde cualquiera de los dos roles que ven la sección.
#
# Yusef: *"cuando termino el manifiesto se bloquea… se bloquea para que nadie lo
# toque. Sí es editable, pero tiene el botón de editar"*, y sobre quién:
# *"tendrían que ser dos de ellos mínimo: el supervisor de Miami y… es que es un
# etiquetador el otro"* → preguntado el 2026-08-30: **"por hoy solo será
# supervisor Miami"**.
class ManifiestoCandadoTest < ActionDispatch::IntegrationTest
  setup do
    @manifiesto = manifiestos(:enviado)   # finalizado ⇒ bloqueado
    @consignatario = Consignatario.create!(nombre: "KARSAM TEST", activo: true)
  end

  def ingresar(user)
    post session_url, params: { email_address: user.email_address, password: "password123" }
  end

  test "el manifiesto finalizado está bloqueado" do
    assert @manifiesto.bloqueado?
  end

  test "el supervisor de Miami abre el candado" do
    assert @manifiesto.editable_por?(users(:supervisor_miami))
  end

  test "el admin también" do
    assert @manifiesto.editable_por?(users(:admin))
  end

  # El etiquetador llega hasta acá porque puede armar manifiestos, pero no
  # puede reabrir uno cerrado.
  test "el digitador de Miami no abre el candado" do
    assert_not @manifiesto.editable_por?(users(:digitador))
  end

  test "un manifiesto abierto lo edita cualquiera que tenga la sección" do
    assert manifiestos(:creado).editable_por?(users(:digitador))
  end

  # El bug de fondo: el candado no frenaba nada.
  test "el digitador no puede cambiar un campo de Miami en uno cerrado" do
    ingresar(users(:digitador))
    assert_nil @manifiesto.consignatario_id, "la fixture arranca sin consignatario"

    patch manifiesto_url(@manifiesto), params: {
      manifiesto: { consignatario_id: @consignatario.id, es_prioridad: true }
    }

    assert_nil @manifiesto.reload.consignatario_id, "el candado no lo dejó entrar"
    assert_not @manifiesto.es_prioridad?
  end

  # Y lo que San Pedro llena después sí pasa — si no, la encargada de
  # operaciones no podría meter la guía ni la fecha (C21-02).
  test "el digitador sí puede llenar lo de San Pedro en uno cerrado" do
    ingresar(users(:digitador))

    patch manifiesto_url(@manifiesto), params: {
      manifiesto: { fecha_aduana: "2026-08-30" }
    }

    assert_equal Date.new(2026, 8, 30), @manifiesto.reload.fecha_aduana.to_date
  end

  test "el supervisor de Miami sí puede cambiar un campo de Miami en uno cerrado" do
    ingresar(users(:supervisor_miami))

    patch manifiesto_url(@manifiesto), params: {
      manifiesto: { consignatario_id: @consignatario.id }
    }

    assert_equal @consignatario.id, @manifiesto.reload.consignatario_id
  end

  # C21-02 · Michelle. Yusef, 2026-08-30: *"Sub-Jefa de área de Caja y SAC"* —
  # o sea de San Pedro, no de Miami — y es de las que llenan la guía del
  # proveedor y la fecha de recibido en Honduras.
  #
  # `CAMPOS_DE_SAN_PEDRO` existía para eso desde PR-M6 y su gente **no podía
  # abrir la pantalla**: la sección era de Miami y nada más.
  #
  # La lista se deriva de `User::ROLES_AUTORIZANTES` justamente para que dé
  # igual si su usuario dice `supervisor_caja` o `supervisor_sac`.
  test "la lista de San Pedro cubre a los tres jefes de Honduras" do
    assert_equal %w[supervisor_prefactura supervisor_caja supervisor_sac].sort,
                 Authorization::ROLES_DE_SAN_PEDRO.sort
  end

  test "la supervisora de San Pedro entra al manifiesto" do
    ingresar(users(:supervisor_prefactura))
    get manifiesto_url(@manifiesto)
    assert_response :success
  end

  test "y llena la fecha de recibido en Honduras y las guías" do
    ingresar(users(:supervisor_prefactura))

    patch manifiesto_url(@manifiesto), params: {
      manifiesto: { fecha_aduana: "2026-08-30" }
    }

    assert_equal Date.new(2026, 8, 30), @manifiesto.reload.fecha_aduana.to_date
  end

  # Entrar no le da los campos de Miami — ni con el manifiesto abierto.
  test "pero no toca lo de Miami, ni en un manifiesto abierto" do
    abierto = manifiestos(:creado)
    assert_not abierto.bloqueado?
    ingresar(users(:supervisor_prefactura))

    patch manifiesto_url(abierto), params: {
      manifiesto: { consignatario_id: @consignatario.id, es_prioridad: true }
    }

    assert_nil abierto.reload.consignatario_id
    assert_not abierto.es_prioridad?
  end

  # Lo que es de Miami de punta a punta: armar y cerrar.
  test "San Pedro no finaliza manifiestos" do
    ingresar(users(:supervisor_prefactura))
    patch finalizar_manifiesto_url(manifiestos(:creado))
    assert_redirected_to root_path
  end

  test "San Pedro no crea manifiestos" do
    ingresar(users(:supervisor_prefactura))
    get new_manifiesto_url
    assert_redirected_to root_path
  end

  # El cajero recibe las cajas, pero no entra a la pantalla del manifiesto.
  test "el cajero sigue afuera" do
    ingresar(users(:cajero))
    get manifiesto_url(@manifiesto)
    assert_redirected_to root_path
  end

  test "el botón «Editar igual» no le sale al digitador" do
    ingresar(users(:digitador))
    get manifiesto_url(@manifiesto)
    assert_response :success
    assert_select "a", text: /Editar igual/, count: 0
  end

  test "y sí le sale al supervisor de Miami" do
    ingresar(users(:supervisor_miami))
    get manifiesto_url(@manifiesto)
    assert_response :success
    assert_select "a", text: /Editar igual/
  end
end
