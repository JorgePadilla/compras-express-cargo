require "test_helper"

# RP-59 · «Expedido por» lo llena el sistema con las iniciales de quien crea el
# manifiesto.
#
# Yusef preguntó él mismo qué iba en ese campo —*"no sé si ponerle las
# iniciales, la firma, el nombre… solamente quien lo hizo"*— y el audio no dejó
# resolver la respuesta: dice «sobre el nombre» cuatro veces, que puede ser
# «sólo el nombre» o «sobrenombre». Jorge lo cerró el 2026-09-02: **las
# iniciales**.
class ManifiestoExpedidoPorTest < ActiveSupport::TestCase
  setup do
    @user = users(:digitador)
    @sucursal = sucursales(:miami)
  end

  test "al crear se estampa con las iniciales de quien lo creó" do
    @user.update!(iniciales: "YS")

    m = crear_manifiesto(user: @user)

    assert_equal "YS", m.expedido_por
  end

  # Las iniciales las define un admin y existen porque *"hay nombres repetidos
  # como Juan"* (`PR-D1.b`). Sin ellas cae al nombre, que es lo que hacía antes.
  test "sin iniciales cargadas cae al nombre" do
    @user.update!(iniciales: nil, nombre: "Vanessa Discua")

    m = crear_manifiesto(user: @user)

    assert_equal "VD", m.expedido_por
  end

  test "sin usuario no inventa a nadie" do
    m = crear_manifiesto(user: nil)

    assert_nil m.expedido_por
  end

  # **El documento va firmado y sellado.** Si el admin le cambia las iniciales
  # a alguien, un manifiesto ya emitido tiene que seguir diciendo lo que decía:
  # por eso se estampa en la columna al crear y no se recalcula nunca.
  test "cambiarle las iniciales al usuario no reescribe manifiestos ya emitidos" do
    @user.update!(iniciales: "YS")
    m = crear_manifiesto(user: @user)

    @user.update!(iniciales: "YSZ")

    assert_equal "YS", m.reload.expedido_por
    assert_equal "YS", crear_otro_manifiesto_y_volver(m)
  end

  # Y guardar el manifiesto por cualquier otra razón tampoco lo toca: el
  # callback es `before_create`, no `before_save`.
  test "actualizar el manifiesto no lo vuelve a estampar" do
    @user.update!(iniciales: "YS")
    m = crear_manifiesto(user: @user)
    otro = users(:supervisor_miami)

    m.update!(user: otro, es_prioridad: true)

    assert_equal "YS", m.reload.expedido_por
  end

  private

  def crear_manifiesto(user:)
    Manifiesto.create!(sucursal_origen: @sucursal, user: user,
                       tipo_envios: [ tipo_envios(:express) ])
  end

  # El estampado no depende de en qué orden se creen: cada manifiesto se lleva
  # las iniciales que había cuando **él** se creó.
  def crear_otro_manifiesto_y_volver(anterior)
    crear_manifiesto(user: @user)
    anterior.reload.expedido_por
  end
end
