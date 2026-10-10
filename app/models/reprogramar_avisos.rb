# PR-P.7 · Cambiar la hora del aviso **en lote**.
#
# Yusef (`C30-16`): *"el marítimo lo notificamos a las 2 de la tarde mientras
# terminamos el aéreo"* · *"le pongo que notifiquemos a las 12… que ya pasó el
# pico"*. La hoja pone la hora al guardar cada pre-factura; esto la corrige
# para todas las de un manifiesto (o las de la hoja) de un tirón, antes de que
# salgan: de 07:30 a 11:30, el mismo día u otro.
#
# **Solo las que no avisaron** (`notificado_at` vacío): a una que ya avisó no
# se le puede cambiar la hora a la que avisó. Y solo las **programadas** (con
# `notificar_at`): una consolidando no tiene hora —espera la carga que
# falta—, y ponerle una la sacaría de consolidando sin que nadie apretara F9.
# `fecha_trabajo` sigue a la hora sola (`PreFactura#ajustar_notificar_at`).
class ReprogramarAvisos
  HORA = HojaDePreparacion::HORA

  class NoSePuede < StandardError; end

  # `pre_facturas`: un scope (las de un manifiesto, las de la hoja).
  # `fecha`: nil deja el día que cada una ya tenía.
  def initialize(pre_facturas, hora:, fecha: nil)
    raise NoSePuede, "La hora va como 11:30." unless hora.to_s.match?(HORA)

    @pre_facturas = pre_facturas
    @h, @m = hora.to_s.split(":").first(2).map(&:to_i)
    @fecha = fecha.present? ? Date.iso8601(fecha.to_s) : nil
  rescue Date::Error
    raise NoSePuede, "La fecha no se entiende."
  end

  def self.reprogramables(scope)
    scope.where(estado: "creado", notificado_at: nil, consolidando_at: nil).where.not(notificar_at: nil)
  end

  # Cuántas se movieron.
  def call
    movidas = 0
    PreFactura.transaction do
      self.class.reprogramables(@pre_facturas).lock.find_each do |pf|
        dia = @fecha || pf.notificar_at.in_time_zone.to_date
        pf.update!(notificar_at: Time.zone.local(dia.year, dia.month, dia.day, @h, @m))
        movidas += 1
      end
    end
    movidas
  end
end
