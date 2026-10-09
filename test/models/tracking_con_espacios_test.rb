require "test_helper"

# C29-01 · El tracking pegado con un espacio en el borde se limpia solo.
#
# Jorge lo pegó con copy-paste y no lo dejó guardar. Yusef: *"tracking no es
# permitido, tienes el espacio este"* — y defendió la regla en la misma frase:
# *"está bien eso, porque tiene que estar bien hecho"*. Así que el borde se
# limpia y el medio sigue siendo error.
class TrackingConEspaciosTest < ActiveSupport::TestCase
  test "los espacios de los bordes se van" do
    paquete = Paquete.new(tracking: "  1Z999AA10123456784 \t", tracking_secundario: " TBA123456789 ")

    assert_equal "1Z999AA10123456784", paquete.tracking
    assert_equal "TBA123456789", paquete.tracking_secundario
  end

  test "un espacio adentro sigue siendo error" do
    paquete = Paquete.new(tracking: "1Z999 AA101")

    paquete.valid?

    assert paquete.errors[:tracking].any?
  end

  test "se encuentra igual con el espacio pegado" do
    # La consulta pasa por la misma normalización: buscar con el espacio del
    # portapapeles encuentra el paquete guardado sin él.
    paquete = paquetes(:disponible_entrega_juan)

    assert_equal paquete, Paquete.find_by(tracking: " #{paquete.tracking} ")
  end
end
