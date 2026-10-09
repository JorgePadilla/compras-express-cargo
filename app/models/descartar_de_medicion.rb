# C26-17 · Quitar un paquete de la lista de pendientes de medición — **solo
# admin**.
#
# Jorge: *"el admin debería poder quitarlos con algunas opciones de perdido, ya
# fue entregado, y una nota si es necesario, pero eso solo el admin"*.
#
# ── Por qué no se le cambia el estado al paquete ──────────────────────────
#
# «Ya fue entregado» como estado sería mentira mientras no haya una entrega
# registrada: el módulo de entregas y la factura leen ese estado. Y «perdido»
# no existe como estado y no se inventa acá. Lo que se sella es una cosa más
# chica y cierta: **esta caja ya no se espera en la estación**, por este motivo,
# puesta por esta persona. El paquete sigue diciendo dónde está de verdad.
class DescartarDeMedicion
  MOTIVOS = { "perdido" => "Perdido", "entregado" => "Ya fue entregado" }.freeze

  class NoPermitido  < StandardError; end
  class SinMotivo    < StandardError; end

  def initialize(paquete:, user:)
    @paquete = paquete
    @user = user
  end

  def descartar!(motivo:, nota: nil)
    validar!
    raise SinMotivo, "Elegí un motivo: perdido o ya fue entregado." unless MOTIVOS.key?(motivo.to_s)

    @paquete.update!(medicion_descartada_at: Time.current,
                     medicion_descartada_por: @user&.iniciales_display,
                     medicion_descartada_motivo: motivo.to_s,
                     medicion_descartada_nota: nota.presence)
    @paquete
  end

  # Se puede deshacer: vuelve a la lista como si nada.
  def restaurar!
    validar!

    @paquete.update!(medicion_descartada_at: nil, medicion_descartada_por: nil,
                     medicion_descartada_motivo: nil, medicion_descartada_nota: nil)
    @paquete
  end

  private

  def validar!
    return if @user&.tiene_rol?("admin")

    raise NoPermitido, "Solo un administrador puede sacar una caja de la lista."
  end
end
