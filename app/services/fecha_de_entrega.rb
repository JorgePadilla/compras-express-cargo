# C31-11 · La «posible fecha de entrega» se cuenta en **días hábiles**.
#
# Yusef, mirando el correo del sistema viejo (*"Posible fecha de entrega:
# sábado"*): *"es días calendario y no días hábiles"*. La regla, con sus
# palabras (16:07 min 12–18):
#
#   > "Contás los días hábiles del lunes a viernes… el último día puede caer un
#   >  sábado, pero no un domingo."
#   > "No puede iniciar el sábado, no puede contar el sábado, solo si es el
#   >  último día."
#
# Y el ejemplo que hizo en voz alta, recibido un viernes: con 10 días cae el
# viernes siguiente; con 11, como el último día es sábado, *"sí lo cuenta"*; con
# 12 el sábado ya no es el último, así que no cuenta y *"cae martes"*.
#
# Entonces, desde el día **siguiente** a la recepción:
#
# - lunes a viernes cuentan, salvo que sean feriado;
# - el domingo no cuenta nunca;
# - el sábado cuenta solo si es el último día (y no el primero: *"no puede
#   iniciar el sábado"*). Un feriado en sábado lo bloquea igual (`RP-101`).
#
# Devuelve un `Date`, o nil si el servicio no tiene días cargados. Las fechas se
# leen en `Time.zone` (Central America), nunca con `Date.today`: un paquete
# recibido a las 7 de la noche en Honduras ya es "mañana" en UTC.
module FechaDeEntrega
  module_function

  def calcular(desde:, dias:)
    dias = dias.to_i
    return nil if desde.blank? || dias <= 0

    dia = desde.in_time_zone.to_date
    feriados = feriados_entre(dia + 1, dia + ventana(dias))
    contados = 0

    loop do
      dia += 1
      next if dia.sunday? || feriados.include?(dia)

      if dia.saturday?
        return dia if contados.positive? && contados == dias - 1

        next
      end

      contados += 1
      return dia if contados == dias
    end
  end

  # Cómo se le dice al cliente: «viernes 23/10». El mismo texto en el correo y
  # en el portal, para que no se lea una fecha distinta en cada lado. En
  # minúscula: el locale trae los días con mayúscula, y va después de dos puntos.
  def texto(fecha)
    I18n.l(fecha.to_date, format: "%A %d/%m").downcase
  end

  # Cuántos días corridos alcanzan para `dias` hábiles, con holgura para una
  # semana santa entera. Es solo para traerse los feriados de una vez y no con
  # una consulta por día.
  def ventana(dias)
    (dias * 7 / 5) + 30
  end

  def feriados_entre(desde, hasta)
    Feriado.where(fecha: desde..hasta).pluck(:fecha).to_set
  end
end
