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

  # C31-08 · Los tres totales de la tarjeta de detalles: pies³, libras y libras
  # volumétricas. Yusef veía *"cero cero libras"* y pidió los tres: *"con eso ya
  # tenemos un cálculo más exacto"*. Lo pintan las dos caras de la tarjeta y el
  # turbo_stream de cada escaneo (`#manifiesto-detalles-pies3/-libras/-vlbs`):
  # un solo texto. Reemplaza al «Peso Total» de PR-C30.15.
  TOTALES_DE_LA_FICHA = [
    [ :pies3, "Pies³", "pies³" ],
    [ :libras, "Libras", "lbs" ],
    [ :vlbs, "Libras vol.", "VLbs" ]
  ].freeze

  def textos_de_totales(manifiesto)
    totales = manifiesto.totales
    TOTALES_DE_LA_FICHA.to_h do |clave, _rotulo, unidad|
      [ clave, "#{number_with_precision(totales[clave], precision: 2, delimiter: ',')} #{unidad}" ]
    end
  end

  def datos_de_totales(manifiesto)
    textos = textos_de_totales(manifiesto)
    safe_join(TOTALES_DE_LA_FICHA.map do |clave, rotulo, _unidad|
      dato_del_manifiesto(rotulo, textos[clave], id: "manifiesto-detalles-#{clave}",
                                                 clase: "text-sm font-semibold text-gray-900")
    end)
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
