module ManifiestosHelper
  # Una fecha y quién la puso, en un renglón: «30/08/2026 · SP».
  #
  # Vive en un helper porque son **tres pantallas** —la bandeja de
  # `/guias-y-aduana`, la ficha del manifiesto y el impreso— y acá lo que se
  # escribe tres veces se desincroniza. Sin fecha devuelve nil, para que cada
  # vista ponga su propio «—» o «Falta».
  def fecha_y_quien(fecha, iniciales, formato: "%d/%m/%Y")
    return nil if fecha.blank?

    [ fecha.strftime(formato), iniciales.presence ].compact.join(" · ")
  end
end
