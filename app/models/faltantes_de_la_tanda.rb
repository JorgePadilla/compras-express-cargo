# C28-13 · Las cajas que faltan en una tanda de medición y que **no** se pueden
# dejar atrás sin que un supervisor ponga su código.
#
# Yusef, el 2026-10-03:
#
#   > "El sistema lo va a dejar pesar porque en el manifiesto este no venían
#   >  más, pero si viene y venían más paquetes no lo debería dejar."
#   > "Para todos estos bloqueos va a haber alguien que lo va a desbloquear, a
#   >  autorizar… con su código."
#   > "Ahí es donde tienen que mandar a buscarlos, o ponerlo a un lado y seguir
#   >  trabajando, y sigamos con el siguiente cliente mientras aparecen."
#
# Una tanda puede tocar **varios grupos** —un consolidado, o los splits de
# varias cajas sueltas—, así que se mira el grupo de cada caja y se juntan las
# que faltan. Qué caja frena lo decide `GrupoDeUnion::Caja#bloquea_si_falta?`.
class FaltantesDeLaTanda
  def initialize(cajas)
    @cajas = Array(cajas)
  end

  # Las `GrupoDeUnion::Caja` que faltan y frenan, sin repetir.
  def bloqueantes
    @bloqueantes ||= begin
      ids = @cajas.map(&:id).to_set
      manifiestos = @cajas.filter_map(&:manifiesto_id).uniq
      grupos.flat_map(&:cajas)
            .reject { |c| c.paquete && ids.include?(c.paquete.id) }
            .select { |c| c.bloquea_si_falta?(manifiestos) }
            .uniq { |c| c.paquete.id }
    end
  end

  def any? = bloqueantes.any?

  private

  # Un grupo cerrado (pre-alerta ya facturada) ya no espera a nadie.
  def grupos
    vistos = Set.new
    @cajas.filter_map do |caja|
      grupo = caja.grupo_de_union
      next if grupo.nil? || grupo.cerrada?

      clave = grupo.pre_alerta&.id || grupo.cajas.map { |c| c.paquete&.id }.sort
      next if vistos.include?(clave)

      vistos << clave
      grupo
    end
  end
end
