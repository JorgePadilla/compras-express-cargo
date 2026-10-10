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

  # PR-C30.15 · Un dato de la tarjeta «Detalles del Manifiesto»: rótulo y
  # valor. Lo usan las dos caras de la tarjeta (solo lectura y formulario), que
  # repiten número, expedido por, fecha enviado, paquetes y peso; escritos dos
  # veces, el id de paquetes y peso —que es por donde el escaneo los sube—
  # tarde o temprano se pierde en una de las dos.
  def dato_del_manifiesto(rotulo, valor, id: nil, clase: "text-sm text-gray-900")
    tag.div do
      tag.dt(rotulo, class: "text-xs font-medium text-gray-500 uppercase tracking-wider") +
        tag.dd(valor, id: id, class: "mt-1 #{clase}")
    end
  end

  # PR-C30.15 · El peso de la tarjeta de detalles. Lo pintan sus dos caras y el
  # turbo_stream de cada paquete (`#manifiesto-detalles-peso`): un solo texto.
  def peso_total_del_manifiesto(manifiesto)
    "#{manifiesto.peso_total || 0} lbs"
  end

  # PR-C30.15 · **Un solo «Editar» (F6)**, arriba en la ficha. Hasta PR-C30.14
  # había dos: el del encabezado, que llevaba a /edit, y el del cartel del
  # candado, que abría lo de adentro — y en la ficha el cartel salía dos veces
  # (arriba y abajo). Jorge, 2026-10-10: *"I want to edit the current view plus
  # all what is in the manifiesto"*.
  #
  # Qué hace depende del manifiesto, y lo decide `encabezado_editable_por?`:
  # - abierto, o con el candado ya abierto, o interno finalizado (C21-06) y el
  #   usuario puede → da vuelta la tarjeta a formulario, adentro de su frame,
  #   sin salir de la ficha;
  # - oficial finalizado con el candado cerrado y el usuario lo puede abrir →
  #   abre el candado (un confirm: *"que presionen el botón"*) y aterriza con
  #   la tarjeta y lo de adentro editables;
  # - el usuario no puede → **no hay botón**. El cartel del candado dice quién.
  def boton_editar_manifiesto(manifiesto, user = Current.user)
    if manifiesto.encabezado_editable_por?(user)
      render ButtonComponent.new(variant: :outline_navy, href: edit_manifiesto_path(manifiesto),
                                 icon: "pencil-square", shortcut: "F6",
                                 data: { turbo_frame: "manifiesto-detalles" }).with_content("Editar")
    elsif manifiesto.reabrible? && manifiesto.editable_por?(user)
      render ButtonComponent.new(variant: :outline_navy, href: abrir_edicion_manifiesto_path(manifiesto),
                                 method: :patch, icon: "lock-open", shortcut: "F6",
                                 confirm: "Se abre #{manifiesto.numero} para corregirlo: el encabezado, las cajas " \
                                          "y los paquetes. Al terminar, «Cerrar edición». ¿Seguro?").with_content("Editar")
    end
  end
end
