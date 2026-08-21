require "test_helper"

# Las reglas del servicio, iguales en las dos pantallas.
#
# Jorge, 2026-08-20: *"el área de pre-alerta para los admin y clientes es muy
# diferente; faltan las reglas de servicio, que son importantísimas, con respecto
# a si se puede con reempaque y consolidación. Revisá la parte de cliente y
# aplicale las reglas al admin"*.
#
# El portal las respetaba las tres y admin ninguna, así que **admin podía grabar
# lo que el portal hace imposible**: una CKA marcada «con reempaque» y
# «consolidado», cuando CKA ni reempaca ni consolida.
class ReglasDelServicioTest < ActiveSupport::TestCase
  setup do
    @cliente = clientes(:juan)
    @cer = tipo_envios(:cer)   # reempaca y consolida
    @cka = tipo_envios(:cka)   # ninguna de las dos, y un solo tracking
  end

  # ── Reempaque: sale del servicio ────────────────────────────────────────

  test "el reempaque lo pone el servicio" do
    assert nueva(@cer).con_reempaque, "CER reempaca"
    assert_not nueva(@cka).con_reempaque, "CKA no reempaca"
  end

  test "mandarlo a mano no lo pisa" do
    # Era el hueco: la casilla de admin dejaba marcar «con reempaque» en CKA.
    pa = nueva(@cka, con_reempaque: true)

    assert_not pa.con_reempaque, "le ganó el parámetro al servicio"
  end

  test "cambiar de servicio lo recalcula" do
    pa = nueva(@cer)
    assert pa.con_reempaque

    pa.update!(tipo_envio: @cka)

    assert_not pa.reload.con_reempaque
  end

  test "guardar sin tocar el servicio no reescribe nada" do
    # No se recalcula en cada guardado: reescribir el dato de una pre-alerta
    # vieja porque alguien le corrigió el título sería tocar historia.
    pa = nueva(@cer)
    pa.update_columns(con_reempaque: false)

    pa.update!(titulo: "se le corrige el título")

    assert_not pa.reload.con_reempaque
  end

  # ── Consolidado: solo si el servicio lo permite ─────────────────────────

  test "no se puede consolidar un servicio que no se consolida" do
    pa = PreAlerta.new(cliente: @cliente, tipo_envio: @cka, titulo: "x",
                       estado: "pre_alerta", consolidado: true)

    assert_not pa.valid?
    assert_match(/no se consolida/, pa.errors.full_messages.to_sentence)
  end

  test "y sí uno que sí" do
    pa = PreAlerta.new(cliente: @cliente, tipo_envio: @cer, titulo: "x",
                       estado: "pre_alerta", consolidado: true)

    assert pa.valid?, pa.errors.full_messages.to_sentence
  end

  test "una vieja que ya quedó así se sigue pudiendo editar" do
    # La trampa de siempre: si la validación corriera en cada guardado, abrir una
    # vieja para corregirle el título la trabaría por algo que nadie tocó.
    pa = nueva(@cer, consolidado: true)
    pa.update_columns(tipo_envio_id: @cka.id)

    vieja = PreAlerta.find(pa.id)
    vieja.titulo = "se le corrige el título"

    assert vieja.valid?, vieja.errors.full_messages.to_sentence
  end

  test "pero cambiarle el servicio a uno que no consolida sí se traba" do
    # Es el camino por el que la contradicción entraría desde la pantalla de
    # editar, que es la gemela de la de crear.
    pa = nueva(@cer, consolidado: true)

    pa.tipo_envio = @cka

    assert_not pa.valid?
    assert_match(/no se consolida/, pa.errors.full_messages.to_sentence)
  end

  # ── Alinear las que ya estaban ──────────────────────────────────────────

  test "las contradictorias se alinean con su servicio" do
    pa = nueva(@cer)
    pa.update_columns(tipo_envio_id: @cka.id, con_reempaque: true, consolidado: true)

    corregidas = PreAlerta.alinear_con_su_servicio!

    assert_includes corregidas.map(&:first), pa.numero_documento
    pa.reload
    assert_not pa.con_reempaque
    assert_not pa.consolidado
  end

  test "llamarla dos veces no hace nada la segunda" do
    pa = nueva(@cer)
    pa.update_columns(tipo_envio_id: @cka.id, con_reempaque: true)
    PreAlerta.alinear_con_su_servicio!

    assert_empty PreAlerta.alinear_con_su_servicio!
  end

  test "las que ya cuadran no se tocan" do
    nueva(@cer, consolidado: true)

    assert_empty PreAlerta.alinear_con_su_servicio!
  end

  test "una anulada no se corrige: es historia" do
    pa = nueva(@cer)
    pa.update_columns(tipo_envio_id: @cka.id, con_reempaque: true, estado: "anulado")

    PreAlerta.alinear_con_su_servicio!

    assert pa.reload.con_reempaque, "le corrigieron una anulada"
  end

  test "ni una facturada, ni una borrada" do
    facturada = nueva(@cer)
    facturada.update_columns(tipo_envio_id: @cka.id, con_reempaque: true, estado: "facturado")
    borrada = nueva(@cer)
    borrada.update_columns(tipo_envio_id: @cka.id, con_reempaque: true, deleted_at: Time.current)

    PreAlerta.alinear_con_su_servicio!

    assert facturada.reload.con_reempaque
    assert borrada.reload.con_reempaque
  end

  private

  def nueva(tipo, **extra)
    PreAlerta.create!({ cliente: @cliente, tipo_envio: tipo, titulo: "Prueba",
                        estado: "pre_alerta" }.merge(extra))
  end
end
