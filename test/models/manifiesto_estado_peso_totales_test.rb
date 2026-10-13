require "test_helper"

# PR-C31.4 · Lo que Yusef pidió del manifiesto el 2026-10-12, probándolo:
#
# - `C31-05`: *"hay que cambiarlo a **enviado a Honduras**"* — y el interno,
#   *"enviado a"* la sucursal.
# - `C31-07`: *"aunque sea inventado, tiene que tener un peso… todas las cajas
#   al final tienen que tener un peso"*.
# - `C31-08`: *"pies, libras y volumétricas… con eso ya tenemos un cálculo más
#   exacto"*.
class ManifiestoEstadoPesoTotalesTest < ActiveSupport::TestCase
  setup do
    Current.session = Struct.new(:user).new(users(:digitador))
    @manifiesto = manifiestos(:creado)
  end

  def paquete_en(manifiesto, **attrs)
    Paquete.create!(
      tracking: "1ZC314#{SecureRandom.hex(5).upcase}", cliente: clientes(:juan),
      tipo_envio: tipo_envios(:cer), sucursal_recepcion: sucursales(:miami),
      estado: "recibido_miami", descripcion: "Perfumes", user: users(:digitador),
      manifiesto: manifiesto, **attrs
    )
  end

  # ── C31-05 ──────────────────────────────────────────────────────────────

  test "el oficial enviado dice «Enviado a Honduras»" do
    assert_equal "Enviado a Honduras", manifiestos(:enviado).estado_texto
  end

  test "el interno enviado dice a qué sucursal" do
    interno = Manifiesto.create!(tipo: "interno", sucursal_origen: sucursales(:zeron_sps),
                                 sucursal_entrega: sucursales(:humuya_tgu),
                                 tipo_envios: [ tipo_envios(:cer) ])
    interno.update_columns(estado: "enviado")

    assert_equal "Enviado a sucursal #{sucursales(:humuya_tgu).nombre}", interno.estado_texto
  end

  test "los otros estados se leen como siempre" do
    assert_equal "Creado", @manifiesto.estado_texto
    @manifiesto.estado = "en_aduana"
    assert_equal "En aduana", @manifiesto.estado_texto
    # Y antes de finalizar ya se sabe cómo va a quedar: lo usa el confirm.
    @manifiesto.estado = "creado"
    assert_equal "Enviado a Honduras", @manifiesto.texto_de_enviado
  end

  # ── C31-07 ──────────────────────────────────────────────────────────────

  test "una caja sin peso no deja finalizar, y no se mueve nada" do
    cer = paquete_en(@manifiesto)
    @manifiesto.cajas.create!(alto: 10, largo: 10, ancho: 10, peso: 12)
    sin_peso = @manifiesto.cajas.create!(alto: 10, largo: 10, ancho: 10)

    resultado = @manifiesto.finalizar!(user: users(:digitador))

    assert resultado.bloqueado?
    assert_equal [ sin_peso ], resultado.cajas_sin_peso
    assert_equal "creado", @manifiesto.reload.estado
    assert_equal "recibido_miami", cer.reload.estado
  end

  test "con todas las cajas pesadas finaliza" do
    paquete_en(@manifiesto)
    @manifiesto.cajas.create!(alto: 10, largo: 10, ancho: 10, peso: 12)

    resultado = @manifiesto.finalizar!(user: users(:digitador))

    assert_not resultado.bloqueado?
    assert_equal "enviado", @manifiesto.reload.estado
  end

  # `C28-05`: la casa se agrega sin peso a propósito; se pide al finalizar.
  test "la caja se puede crear sin peso" do
    assert @manifiesto.cajas.create(alto: 10, largo: 10, ancho: 10).persisted?
  end

  # ── C31-08 ──────────────────────────────────────────────────────────────

  test "con cajas, los tres totales salen de las cajas" do
    @manifiesto.cajas.create!(alto: 12, largo: 12, ancho: 12, peso: 20)   # 1 pie³
    @manifiesto.cajas.create!(alto: 24, largo: 12, ancho: 12, peso: 30.5) # 2 pies³

    totales = @manifiesto.totales

    assert_equal 3, totales[:pies3]
    assert_equal BigDecimal("50.5"), totales[:libras]
    assert_equal @manifiesto.cajas.sum(:volumen), totales[:vlbs]
  end

  test "sin cajas, salen de los paquetes" do
    paquete_en(@manifiesto, alto: 12, largo: 12, ancho: 12, peso: 8, volumen: 10.41)
    paquete_en(@manifiesto)   # sin medidas: no suma pies³

    totales = @manifiesto.totales

    assert_equal 1, totales[:pies3]
    # Lo que se cobra (`peso_cobrar`, el mayor entre peso y volumen ya
    # redondeado), igual que `recalculate_totals!`.
    assert_equal Paquete.where(manifiesto: @manifiesto).sum(:peso_cobrar), totales[:libras]
    assert totales[:libras].positive?
    assert_equal Paquete.where(manifiesto: @manifiesto).sum(:volumen), totales[:vlbs]
  end
end
