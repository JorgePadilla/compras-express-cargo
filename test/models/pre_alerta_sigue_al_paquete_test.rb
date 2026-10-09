require "test_helper"

# A7-19: la pre-alerta sigue al paquete cuando Miami lo recibe con otro servicio.
#
# Yusef lo reprodujo en vivo el 2026-08-12, y le costó entenderlo tanto como a
# Jorge — estuvieron un rato escaneando el mismo tracking sin saber por qué
# volvía a proponer el servicio viejo:
#
#   > "Este tracking está en Express… la prealerta era CER, pero tenés que
#   >  actualizarla a Express."
#   > "Ahí es donde tenés que irte a la prealerta y sacarlo de ahí."
#
# Lo estaba corrigiendo a mano porque nada en el repo escribía
# `pre_alertas.tipo_envio_id` después de crearla.
class PreAlertaSigueAlPaqueteTest < ActiveSupport::TestCase
  setup do
    @cer = tipo_envios(:cer)
    @cem = tipo_envios(:cem)
    @cliente = clientes(:juan)
  end

  test "cambiar el servicio del paquete arrastra la pre-alerta" do
    pa = crear_pre_alerta(@cer)
    paquete = pa.pre_alerta_paquetes.first.paquete

    paquete.aplicar_cambio_servicio(@cem)
    paquete.save!

    assert_equal @cem, pa.reload.tipo_envio,
                 "la pre-alerta se quedó con el servicio viejo — el cliente lo ve así en su portal"
  end

  test "queda anotado en el historial de que a que se movio" do
    pa = crear_pre_alerta(@cer)
    paquete = pa.pre_alerta_paquetes.first.paquete

    paquete.aplicar_cambio_servicio(@cem)
    paquete.save!

    assert_match(/#{@cer.nombre}.*#{@cem.nombre}/, pa.reload.historial.to_s)
    assert_match(/Miami/i, pa.historial.to_s)
  end

  test "no se toca la pre-alerta si el tipo no cambio" do
    pa = crear_pre_alerta(@cer)
    paquete = pa.pre_alerta_paquetes.first.paquete
    historial_antes = pa.historial.to_s

    paquete.update!(peso: 99)

    assert_equal historial_antes, pa.reload.historial.to_s
  end

  # Dos paquetes de la misma pre-alerta con cambios de servicio distintos: no
  # hay forma de saber cuál manda, así que no se adivina.
  test "si los paquetes divergen no se sincroniza, se anota" do
    pa = crear_pre_alerta(@cer, paquetes: 2)
    primero, segundo = pa.pre_alerta_paquetes.map(&:paquete)

    primero.aplicar_cambio_servicio(@cem)
    primero.save!

    assert_equal @cer, pa.reload.tipo_envio, "eligió uno de los dos por su cuenta"
    assert_match(/distintos/i, pa.historial.to_s)
    assert_equal @cer, segundo.reload.tipo_envio, "le movió el servicio al otro paquete"
  end

  # `respect_max_paquetes_por_accion` puede rechazar el tipo nuevo. Que la
  # pre-alerta no se pueda actualizar no puede tumbar la recepción del paquete.
  test "si la pre-alerta rechaza el tipo nuevo, el paquete igual se guarda" do
    ckm = tipo_envios(:ckm)
    skip "el fixture de CKM no limita paquetes por acción" unless ckm.single_package?

    pa = crear_pre_alerta(@cer, paquetes: 2)

    # Los dos pasan a CKM: ya coinciden, así que se intenta sincronizar — y la
    # pre-alerta lo rechaza porque CKM admite un solo paquete.
    pa.pre_alerta_paquetes.map(&:paquete).each do |p|
      p.aplicar_cambio_servicio(ckm)
      assert_nothing_raised { p.save! }
    end

    assert_equal ckm, pa.pre_alerta_paquetes.first.paquete.reload.tipo_envio,
                 "el paquete no se guardó porque la pre-alerta se quejó"
    assert_equal @cer, pa.reload.tipo_envio
    assert_match(/no se pudo/i, pa.historial.to_s)
  end

  private

  def crear_pre_alerta(tipo, paquetes: 1)
    pa = PreAlerta.create!(cliente: @cliente, tipo_envio: tipo,
                           estado: "pre_alerta", titulo: "Prueba A7-19")
    paquetes.times do |i|
      pa.pre_alerta_paquetes.create!(tracking: "A719#{i}#{SecureRandom.hex(3)}",
                                     descripcion: "Caja #{i + 1}")
    end
    pa.reload
  end
end
