require "test_helper"

# PR: con qué se pagó, cuando el paquete se pagó en Miami.
#
# Yusef: *"ya vi el pagado en Miami, está bien, solo faltó algo que
# conversamos: que escogieran cómo se pagó — efectivo o Zelle o TC"*.
#
# El marcado guardaba quién, cuándo y en qué sucursal, pero no con qué. Cuando
# el paquete llega a Honduras el cajero arma el cobro simbólico a ciegas.
class PaquetePrepagoMiamiTest < ActiveSupport::TestCase
  setup { @paquete = paquetes(:recibido) }

  test "un paquete que se marca como pagado en Miami tiene que decir como" do
    @paquete.prepagado_miami = true

    assert_not @paquete.valid?
    assert_includes @paquete.errors[:prepagado_miami_metodo], "hay que decir cómo se pagó"
  end

  test "una forma de pago inventada no se guarda" do
    @paquete.assign_attributes(prepagado_miami: true, prepagado_miami_metodo: "bitcoin")

    assert_not @paquete.valid?
    assert_includes @paquete.errors[:prepagado_miami_metodo], "no es una forma de pago de Miami"
  end

  test "un metodo colgado sin prepago no se guarda" do
    # El caso del que se arrepintió a mitad: marca el prepago, elige Zelle y
    # vuelve a "cobrar en Honduras". Si el método queda, la pre-factura y el
    # Warehouse Receipt dicen que se pagó algo que no se pagó.
    @paquete.assign_attributes(prepagado_miami: false, prepagado_miami_metodo: "zelle")

    assert_not @paquete.valid?
    assert_includes @paquete.errors[:prepagado_miami_metodo],
                    "solo aplica si el paquete se pagó en Miami"
  end

  test "los tres metodos de Miami se guardan" do
    Paquete::METODOS_PREPAGO_MIAMI.each do |metodo|
      @paquete.assign_attributes(prepagado_miami: true, prepagado_miami_metodo: metodo)

      assert @paquete.valid?, "#{metodo} debería servir: #{@paquete.errors.full_messages}"
    end
  end

  test "un paquete viejo, prepagado antes de que existiera la columna, se sigue pudiendo guardar" do
    # Exigirle el método a los que ya estaban marcados los volvería imposibles
    # de tocar desde cualquier pantalla que no tenga dónde elegirlo — y no
    # tenemos cómo saber con qué pagaron. `nil` ahí significa "es de antes".
    @paquete.update_columns(prepagado_miami: true, prepagado_miami_metodo: nil)
    viejo = Paquete.find(@paquete.id)
    viejo.descripcion = "se edita otra cosa"

    assert viejo.valid?, viejo.errors.full_messages.to_sentence
    assert viejo.save
  end

  test "pero si a ese viejo le vuelven a marcar el prepago, ahi si tiene que decir como" do
    @paquete.update_columns(prepagado_miami: false, prepagado_miami_metodo: nil)
    viejo = Paquete.find(@paquete.id)
    viejo.prepagado_miami = true

    assert_not viejo.valid?
  end

  # ── Las dos listas son distintas a propósito ────────────────────────────

  test "zelle es de Miami y NO de la caja de Honduras" do
    # `Pago`, `IngresoCaja` y `EgresoCaja` comparten `%w[efectivo tarjeta
    # transferencia]`. Zelle no se recibe en la caja de Honduras: meterlo en esa
    # lista lo haría aparecer en tres pantallas donde no aplica.
    assert_includes Paquete::METODOS_PREPAGO_MIAMI, "zelle"
    assert_not_includes Pago::METODOS, "zelle"
  end

  test "cada metodo tiene su rotulo en castellano" do
    sin_rotulo = Paquete::METODOS_PREPAGO_MIAMI.reject { |m| Paquete::ETIQUETAS_METODO_PREPAGO.key?(m) }

    assert_empty sin_rotulo
  end

  # ── El formato, en un solo lugar ────────────────────────────────────────

  test "el sufijo sale igual para el Warehouse Receipt y para la pre-factura" do
    @paquete.assign_attributes(prepagado_miami: true, prepagado_miami_metodo: "zelle")

    assert_equal "Zelle", @paquete.metodo_prepago_label
    assert_equal " · ZELLE", @paquete.prepago_sufijo
  end

  test "sin metodo el sufijo es vacio, no un separador colgando" do
    # Si devolviera " · " el badge diría "PREPAGADO EN MIAMI ·" y parecería que
    # falta algo por cargar.
    @paquete.update_columns(prepagado_miami: true, prepagado_miami_metodo: nil)

    assert_equal "", Paquete.find(@paquete.id).prepago_sufijo
    assert_nil Paquete.find(@paquete.id).metodo_prepago_label
  end
end
