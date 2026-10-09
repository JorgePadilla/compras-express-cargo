require "test_helper"

# PR: las dos cosas que Yusef pidió de la pre-alerta de admin.
class PreAlertaAdminReglasTest < ActiveSupport::TestCase
  setup do
    @cliente = clientes(:juan)
    @tipo = tipo_envios(:cer)
  end

  # ── Sin consolidar, un solo paquete ─────────────────────────────────────

  test "sin consolidar no deja cargar dos paquetes" do
    # Yusef: "no marqué consolidado y me deja agregar más de 1, siempre en
    # admin". La regla existía solo en la vista del portal.
    pa = nueva(consolidado: false)
    pa.pre_alerta_paquetes.build(tracking: "A1", descripcion: "uno")
    pa.pre_alerta_paquetes.build(tracking: "A2", descripcion: "dos")

    assert_not pa.valid?
    assert_match(/un solo paquete/, pa.errors.full_messages.to_sentence)
  end

  test "con consolidado deja los que sean" do
    pa = nueva(consolidado: true)
    3.times { |i| pa.pre_alerta_paquetes.build(tracking: "B#{i}", descripcion: "x") }

    assert pa.valid?, pa.errors.full_messages.to_sentence
  end

  test "sin consolidar, uno solo pasa" do
    pa = nueva(consolidado: false)
    pa.pre_alerta_paquetes.build(tracking: "C1", descripcion: "uno")

    assert pa.valid?
  end

  test "una pre-alerta que YA estaba asi se sigue pudiendo guardar" do
    # La trampa de siempre: si la validación corriera en cada guardado, abrir
    # una vieja para corregirle el título la trabaría con un error de algo que
    # nadie tocó. Es lo mismo que pasó con el método de prepago.
    pa = nueva(consolidado: true)
    2.times { |i| pa.pre_alerta_paquetes.build(tracking: "D#{i}", descripcion: "x") }
    pa.save!
    pa.update_column(:consolidado, false)

    vieja = PreAlerta.find(pa.id)
    vieja.titulo = "se le corrige el título"

    assert vieja.valid?, vieja.errors.full_messages.to_sentence
    assert vieja.save
  end

  test "pero agregarle otro a esa vieja si se traba" do
    pa = nueva(consolidado: true)
    pa.pre_alerta_paquetes.build(tracking: "E1", descripcion: "x")
    pa.save!
    pa.update_column(:consolidado, false)

    vieja = PreAlerta.find(pa.id)
    vieja.pre_alerta_paquetes.build(tracking: "E2", descripcion: "x")

    assert_not vieja.valid?
  end

  # ── Retener en Miami ────────────────────────────────────────────────────

  test "la retencion viaja al paquete esperado" do
    # Yusef: "nos hace falta la opción de Retener en Miami en Pre Alerta de
    # Admin". El que recibe en Miami tiene que verlo ya marcado.
    pa = nueva(consolidado: false)
    pap = pa.pre_alerta_paquetes.build(tracking: "F1", descripcion: "x", retener_miami: true)
    pa.save!

    assert pap.reload.paquete.retener_miami?
  end

  test "marcarla despues tambien llega al paquete" do
    # Sin esto la bandera solo funcionaba al crear, y editar la pre-alerta
    # dejaba el paquete esperado sin marcar.
    pa = nueva(consolidado: false)
    pap = pa.pre_alerta_paquetes.build(tracking: "G1", descripcion: "x")
    pa.save!
    assert_not pap.reload.paquete.retener_miami?

    pap.update!(retener_miami: true)

    assert pap.reload.paquete.retener_miami?
  end

  test "sin marcar, el paquete no nace retenido" do
    pa = nueva(consolidado: false)
    pap = pa.pre_alerta_paquetes.build(tracking: "H1", descripcion: "x")
    pa.save!

    assert_not pap.reload.paquete.retener_miami?
  end

  private

  def nueva(consolidado:)
    PreAlerta.new(cliente: @cliente, tipo_envio: @tipo, titulo: "Prueba",
                  estado: "pre_alerta", consolidado: consolidado)
  end
end
