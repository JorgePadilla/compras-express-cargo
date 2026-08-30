# C21-07 · El correo por las cajas que no llegaron.
#
# `A7-06`, de la Conversación 7: *"si falta una caja, manda un correo al correo
# tal"*. Es el único aviso fuera de la pantalla, porque el que recibe ya siguió
# trabajando y el faltante lo tiene que ver alguien más.
class ManifiestoMailer < ApplicationMailer
  def cajas_faltantes(manifiesto, faltantes)
    @manifiesto = manifiesto
    @faltantes = faltantes

    mail(to: destino, subject: "Faltan #{faltantes.size} caja(s) del manifiesto #{manifiesto.numero}")
  end

  private

  # Sin catálogo propio todavía: va al mismo destino que el resto de los avisos
  # internos. Cuando Yusef diga «al correo tal», sale de configuración.
  def destino
    Configuracion.get("correo_avisos_internos").presence || ApplicationMailer.default[:from]
  end
end
