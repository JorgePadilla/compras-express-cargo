require "test_helper"

# C19-05. Yusef: "cuando revisamos cámaras, en un segundo pueden pasar tres o
# cuatro paquetes… ese segundo es como el paquete exacto… Roger le quitó los
# segundos por una mala interpretación de él".
#
# El segundo del F9 vive en `fecha_recibido_miami` — pero el flatpickr del
# form de /paquetes edita al minuto, así que cualquier guardado desde ahí
# re-parseaba la fecha con :00 y el segundo se borraba en silencio. La regla:
# si el minuto no cambió, el "cambio" es solo la pérdida del segundo y se
# conserva el momento original.
class PaqueteSegundosDeFechasTest < ActiveSupport::TestCase
  setup do
    @paquete = paquetes(:disponible_entrega_juan)
    @momento = Time.zone.local(2026, 8, 28, 10, 15, 47)
    @paquete.update_columns(fecha_recibido_miami: @momento)
    @paquete.reload
  end

  test "editar otra cosa no borra el segundo" do
    # Lo que manda el form: la misma fecha, pero al minuto.
    @paquete.fecha_recibido_miami = Time.zone.local(2026, 8, 28, 10, 15, 0)
    @paquete.descripcion = "Corregida"
    @paquete.save!

    assert_equal @momento, @paquete.reload.fecha_recibido_miami,
                 "el segundo del F9 se borró al editar otro campo"
  end

  test "y el diff de paper_trail no registra un cambio que no fue" do
    @paquete.fecha_recibido_miami = Time.zone.local(2026, 8, 28, 10, 15, 0)
    @paquete.descripcion = "Otra corrección"
    @paquete.save!

    cambios = @paquete.versions.last&.changeset || {}
    assert_not cambios.key?("fecha_recibido_miami"),
               "paper_trail registró como cambio la pérdida del segundo"
  end

  test "cambiar el minuto a propósito sí entra" do
    nuevo = Time.zone.local(2026, 8, 28, 11, 30, 0)
    @paquete.fecha_recibido_miami = nuevo
    @paquete.save!

    assert_equal nuevo, @paquete.reload.fecha_recibido_miami
  end

  test "la regla cubre las demás fechas editables" do
    enviado = Time.zone.local(2026, 8, 20, 14, 22, 33)
    @paquete.update_columns(fecha_enviado: enviado)
    @paquete.reload

    @paquete.fecha_enviado = Time.zone.local(2026, 8, 20, 14, 22, 0)
    @paquete.save!

    assert_equal enviado, @paquete.reload.fecha_enviado
  end
end
