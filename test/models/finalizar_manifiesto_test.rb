require "test_helper"

# C21-06 · Finalizar el manifiesto.
#
# Del diagrama que dibujó Yusef: **«Finalizar e imprimir todos los paquetes con
# el tipo de envío nuestro seleccionado» → cambia estatus a ENVIADO**. Y el
# bloqueo que describió después: *"cuando termino el manifiesto se bloquea… se
# bloquea para que nadie lo [toque]. Sí es editable, pero tiene el botón de
# editar"*.
class FinalizarManifiestoTest < ActiveSupport::TestCase
  setup do
    Current.session = Struct.new(:user).new(users(:digitador))
    @manifiesto = manifiestos(:creado)   # lleva CER por fixture
    @cer = crear_paquete(tipo_envios(:cer))
  end

  test "los paquetes del tipo seleccionado pasan a enviado" do
    resultado = @manifiesto.finalizar!(user: users(:digitador))

    assert_equal [ @cer ], resultado.enviados
    assert_equal "enviado_honduras", @cer.reload.estado
    assert_equal "enviado", @manifiesto.reload.estado
  end

  # *"Todos los paquetes con el tipo de envío nuestro seleccionado."* El que
  # entró por «omitir» con otro tipo no es de los que este manifiesto declara.
  test "un paquete de otro tipo no sale con este manifiesto" do
    otro = crear_paquete(tipo_envios(:cem))

    @manifiesto.finalizar!(user: users(:digitador))

    assert_equal "recibido_miami", otro.reload.estado
  end

  # Lo que el `update_all` no hacía. Tres cosas se ganan de un solo cambio.
  test "finalizar deja bitácora y estampa quién y cuándo — lo que el update_all no hacía" do
    assert_difference -> { PaperTrail::Version.where(item_type: "Paquete").count }, 1 do
      @manifiesto.finalizar!(user: users(:digitador))
    end

    assert @cer.reload.fecha_enviado.present?, "el ESTADO_FECHA_MAP estampa la fecha"
    assert_equal users(:digitador).id, @cer.fecha_enviado_by_user_id,
                 "y quién lo mandó, que con update_all quedaba en nil"
  end

  # La guarda que el `update_all` se saltaba. Y no puede trabar a los demás:
  # misma forma que `A7-05` eligió para la recepción parcial — avisar con el
  # faltante enumerado, no bloquear.
  test "un paquete con tarea abierta no pasa, y no traba a los demás" do
    trabado = crear_paquete(tipo_envios(:cer))
    Tarea.create!(paquete: trabado, titulo: "Falta la factura", estado: "pendiente",
                  bloquea_avance: true)

    resultado = @manifiesto.finalizar!(user: users(:digitador))

    assert_includes resultado.enviados, @cer, "los demás pasaron igual"
    assert_equal 1, resultado.trabados.size
    assert_equal trabado, resultado.trabados.first.first
    assert_equal "recibido_miami", trabado.reload.estado
  end

  test "el manifiesto queda bloqueado, y guarda quién lo finalizó" do
    @manifiesto.finalizar!(user: users(:digitador))
    @manifiesto.reload

    assert @manifiesto.bloqueado?
    assert_equal users(:digitador), @manifiesto.finalizado_por
    assert @manifiesto.finalizado_at.present?
  end

  test "no se finaliza dos veces" do
    @manifiesto.finalizar!(user: users(:digitador))

    assert_raises(ArgumentError) { @manifiesto.reload.finalizar!(user: users(:digitador)) }
  end

  teardown { Current.session = nil }

  private

  def crear_paquete(tipo)
    Paquete.create!(
      tracking: "1ZFIN#{SecureRandom.hex(5).upcase}", cliente: clientes(:juan), tipo_envio: tipo,
      sucursal_recepcion: sucursales(:miami), estado: "recibido_miami",
      descripcion: "Perfumes", user: users(:digitador), manifiesto: @manifiesto
    )
  end
end
