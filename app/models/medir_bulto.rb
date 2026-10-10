# C26-19 · Guardar una tanda de medición: las cajas que el operario escaneó,
# los volúmenes que sacó de ellas, y el sello en cada caja.
#
# Todo entra junto, como las cajas de /etiquetar (`A7-21`: *"cuando menos
# acordás me salieron cuatro en vez de cinco"*): al imprimir ya se sabe cuántas
# mediciones son, y eso es lo que dice el «1 de 2» del QR.
#
# C28-08 · **Las cajas son de la tanda, no de un volumen.** Hasta el 2026-10-03
# cada volumen llevaba sus cajas —se escaneaban tres, se medía, se escaneaban
# dos, se medía—. La línea de San Pedro lo probó en vivo y lo dio vuelta: *"la
# medición la va a decidir después de haber escaneado… para ellos es mejor solo
# escanear, que sí están ahí, y ellos lo acomodan como gustan para medir y
# pesar"*. Ahora se escanea todo y después salen los N volúmenes, cada uno con
# sus números y ninguno con cajas: la tanda entera queda con una sola sesión,
# que es la que comparten sus cajas y sus bultos.
#
# Reemplaza a `MedirPaquete` para el camino nuevo. `MedirPaquete` sigue vivo
# porque un bulto de una sola caja no es un caso especial: es el mismo servicio
# con una caja adentro.
class MedirBulto
  class NoSePuede < StandardError; end

  # C28-13 · Faltan cajas que vinieron, y nadie puso su código todavía. Lleva
  # la lista para que la pantalla la muestre en el modal del PIN.
  class NecesitaAutorizacion < NoSePuede
    attr_reader :faltantes

    def initialize(mensaje, faltantes)
      super(mensaje)
      @faltantes = faltantes
    end
  end

  # C27-14 · `saltar_manifiesto` son las cajas que el operario autorizó a medir
  # aunque **no hayan pasado por el manifiesto**. Yusef, mirando el bloqueo en
  # vivo: *"este tiene un bloqueo ahorita que me tiene loco: si no ha pasado el
  # proceso desde Miami para acá, no lo puede hacer… **hay que poner una opción
  # ahí**"*. Y el porqué: *"debe dejar que sí se lo salten, porque a veces se
  # capean, algunos se los van a capear"*.
  #
  # La lista viene de la pantalla, caja por caja: no es un modo, es una
  # excepción con nombre, y cada una queda sellada en su paquete.
  def initialize(user:, saltar_manifiesto: [])
    @user = user
    @saltar = Array(saltar_manifiesto).map(&:to_i).to_set
  end

  # `paquete_ids` son las cajas de la tanda **en el orden en que se
  # escanearon** —«NO Mezclar» compara todo contra la primera—; `volumenes`,
  # una lista de `{ peso:, alto:, largo:, ancho: }` en el orden en que se
  # agregaron. `reemplaza_sesion` es la tanda que se está midiendo de nuevo
  # (`C27-33`): sus bultos se van y sus cajas pueden volver a entrar.
  #
  # `autorizacion` es `{ supervisor_id:, pin:, motivo: }`, y solo hace falta
  # cuando a la tanda le faltan cajas que vinieron (`FaltantesDeLaTanda`).
  def guardar!(paquete_ids:, volumenes:, reemplaza_sesion: nil, autorizacion: nil)
    lista = Array(volumenes).map { |v| v.respond_to?(:to_unsafe_h) ? v.to_unsafe_h : v.to_h }
    raise NoSePuede, "No hay ningún volumen que guardar: poné al menos el peso." if lista.empty?
    raise NoSePuede, demasiadas_msg if lista.size > Bulto::MAXIMO_POR_SESION

    reemplaza_sesion = reemplaza_sesion.presence
    if reemplaza_sesion && !Bulto.exists?(sesion: reemplaza_sesion)
      raise NoSePuede, "La tanda que se quería corregir ya no existe. Escaneá la caja otra vez."
    end
    if reemplaza_sesion && (pf = Bulto.pre_factura_que_cobra(reemplaza_sesion))
      raise NoSePuede, "Esa tanda ya se cobra en la pre-factura #{pf.numero}: sus volúmenes no se pueden " \
                       "medir de nuevo desde acá. Anulá la pre-factura primero."
    end

    cajas = cajas_de(paquete_ids)
    numeros = lista.map { |v| numeros_de(v) }
    validar!(cajas, reemplaza_sesion)
    permiso = permiso_por_faltantes(cajas, autorizacion)

    sesion = SecureRandom.uuid
    ahora = Time.current

    Bulto.transaction do
      permiso&.save!
      reemplazar!(reemplaza_sesion, cajas) if reemplaza_sesion
      # Primero las cajas y después los bultos: el `peso_cobrar` del bulto lee
      # el trato de cobro de las cajas, y tienen que estar ya en la tanda.
      cajas.each do |caja|
        caja.update!(medicion_sesion: sesion, medido_at: ahora, medido_por: @user&.iniciales_display,
                     **sello_de_salto(caja, ahora))
      end
      numeros.each_with_index.map do |n, i|
        Bulto.create!(cliente: cajas.first.cliente, user: @user, sesion: sesion,
                      orden: i + 1, de_cuantos: numeros.size, medido_at: ahora,
                      medido_por: @user&.iniciales_display, **n)
      end
    end
  end

  private

  # C28-13 · Si faltan cajas que vinieron, hace falta el código de un
  # supervisor; sin él no se guarda nada. El registro queda en la bitácora de
  # autorizaciones con quién, por qué y **qué faltaba**, que es lo que después
  # se audita. Se valida acá, antes de escribir: un PIN malo no deja nada.
  def permiso_por_faltantes(cajas, autorizacion)
    faltantes = FaltantesDeLaTanda.new(cajas)
    return nil unless faltantes.any?

    lista = faltantes.bloqueantes
    datos = (autorizacion || {}).to_h.symbolize_keys
    raise NecesitaAutorizacion.new(faltantes_msg(lista), lista) if datos[:supervisor_id].blank?

    permiso = Autorizacion.new(
      documento: cajas.first, solicitado_por: @user,
      autorizado_por: User.find_by(id: datos[:supervisor_id]),
      accion: "medicion_con_faltantes", pin: datos[:pin].to_s, motivo: datos[:motivo].to_s,
      concepto: concepto_de(cajas.first),
      detalle: "Faltaban #{lista.size}: #{lista.map { |c| "#{codigo(c.paquete)} (#{c.donde})" }.join(', ')}".truncate(250)
    )
    raise NecesitaAutorizacion.new(permiso.errors.full_messages.to_sentence, lista) unless permiso.valid?

    permiso
  end

  def concepto_de(caja)
    caja.grupo_de_union&.pre_alerta&.numero_documento || codigo(caja)
  end

  def faltantes_msg(lista)
    "Faltan #{lista.size} caja#{"s" if lista.size != 1} que sí vinieron: " \
      "#{lista.map { |c| codigo(c.paquete) }.join(', ')}. Mandalas a buscar, o que un supervisor ponga su código."
  end

  # C27-33 · Medir de nuevo: los volúmenes viejos se van y los nuevos ocupan
  # su lugar. Las cajas que el operario **sacó** de la tanda vuelven a estar
  # sin medir —y a la lista de pendientes—, porque el único número que tenían
  # era el de la tanda que acaba de morir. `has_paper_trail` en `Bulto` guarda
  # los números viejos con quién los puso.
  def reemplazar!(sesion, cajas_nuevas)
    ids = cajas_nuevas.map(&:id)
    Paquete.where(medicion_sesion: sesion).where.not(id: ids).find_each do |caja|
      caja.update!(medicion_sesion: nil, medido_at: nil, medido_por: nil)
    end
    Bulto.where(sesion: sesion).where.not(id: PreFacturaItem.where.not(bulto_id: nil).select(:bulto_id))
         .find_each(&:destroy!)
  end

  # PR-P.1 · Medir de nuevo no sigue si una pre-factura **viva** cobra algún
  # volumen de la tanda: el volumen es la línea que le cobra al cliente
  # (`Bulto has_many :pre_factura_items, restrict`), y borrarlo dejaría la
  # pre-factura cobrando un número que ya no existe. La pregunta vive en
  # `Bulto.pre_factura_que_cobra` (PR-P.11a: `MarcarCobroExcepcion` la hace
  # también).
  #
  # Una pre-factura **anulada** no frena: sus cajas ya volvieron a estar
  # libres (`anular!`) y medirlas de nuevo es justamente lo que se hace
  # después. Esos volúmenes viejos no se borran —el documento anulado los
  # sigue nombrando— y quedan huérfanos de su tanda: ninguna caja tiene ya su
  # sesión, así que nada los vuelve a contar.

  # En el orden en que vinieron, que es el del escaneo: `where(id:)` los
  # devuelve en el que se le ocurra a la base, y «NO Mezclar» le dice al
  # operario cuál choca **con la primera**.
  def cajas_de(paquete_ids)
    ids = Array(paquete_ids).map(&:to_i).reject(&:zero?)
    raise NoSePuede, "La tanda no tiene ninguna caja escaneada." if ids.empty?

    repetida = ids.tally.find { |_id, veces| veces > 1 }&.first
    por_id = Paquete.where(id: ids.uniq).includes(:cliente, :tipo_envio, :proveedor, :sucursal).index_by(&:id)
    raise NoSePuede, "Alguna de las cajas escaneadas ya no existe." if por_id.size != ids.uniq.size
    raise NoSePuede, repetida_msg(por_id[repetida]) if repetida

    ids.map { |id| por_id[id] }
  end

  # La misma regla que `MedirPaquete`: al menos uno de los cuatro, y las tres
  # medidas van juntas o no van.
  def numeros_de(volumen)
    valores = MedirPaquete::CAMPOS.index_with { |c| volumen[c] || volumen[c.to_s] }
    numeros = MedirPaquete.numeros_de(valores)
    raise NoSePuede, sin_nada_msg if numeros.empty?
    raise NoSePuede, a_medias_msg if dimensiones_a_medias?(numeros)

    numeros
  end

  def dimensiones_a_medias?(numeros)
    puestas = MedirPaquete::DIMENSIONES.count { |d| numeros.key?(d) }
    puestas.positive? && puestas < MedirPaquete::DIMENSIONES.size
  end

  # Las guardas de siempre, caja por caja, **antes** de escribir nada; más
  # «NO Mezclar» sobre toda la tanda: sus cajas son del mismo cliente y del
  # mismo servicio, y del mismo consolidado si lo hay.
  #
  # PR-P.11a · Con `misma_tanda`: también la misma sucursal, el mismo prepago,
  # la misma tarifa y el mismo trato de cobro — lo que el volumen necesita para
  # cobrarse con una sola línea. La pantalla ya lo frena al escanear; esto es
  # la red para la pestaña vieja o el pedido armado a mano.
  def validar!(cajas, reemplaza_sesion)
    cajas.each { |caja| validar_caja!(caja, reemplaza: reemplaza_sesion) }

    cajas.each_with_index do |caja, i|
      next if i.zero?

      problema = PuedenIrJuntas.new(cajas.first(i), caja, misma_tanda: true).problema
      raise NoSePuede, problema.mensaje if problema
    end
  end

  def validar_caja!(caja, reemplaza: nil)
    if caja.pre_factura_id.present? || caja.venta_id.present?
      raise NoSePuede, "#{codigo(caja)} ya está en una pre-factura: el peso se congeló ahí."
    end
    # Una caja que ya está en una tanda solo entra si esta medición viene a
    # reemplazar **esa** tanda: si no, es un pip sobre una caja ya medida y la
    # pantalla tiene que haber preguntado antes.
    if caja.medicion_sesion.present? && caja.medicion_sesion != reemplaza
      raise NoSePuede, "#{codigo(caja)} ya está medida. Para corregirla, escaneala y elegí «Medir de nuevo»."
    end
    return if caja.estado.in?(Paquete::ESTADOS_FACTURABLES)
    # C27-14 · La caja **está en la mesa, en la mano del operario**: el estado
    # dice que no pasó por el manifiesto, y eso se avisa, pero no bloquea si
    # alguien puso su nombre. *"Pero si ya está en Honduras. ¿Cómo llegó a
    # Honduras si no…? Debe dejar que sí se lo salten."*
    return if salto?(caja)

    raise NoSePuede, "#{codigo(caja)} está «#{caja.estado.to_s.humanize}»: todavía no se recibió. " \
                     "Pasala por Recibir Carga."
  end

  # Ésta se está midiendo saltándose el manifiesto: la autorizaron y su estado
  # no da. Si el estado sí da, no hay nada que sellar aunque venga en la lista.
  def salto?(caja)
    @saltar.include?(caja.id) && !caja.estado.in?(Paquete::ESTADOS_FACTURABLES)
  end

  # Lo que se guarda de la excepción: quién, cuándo, y **en qué estado estaba**
  # —que es el dato que después se audita—. El estado del paquete no se toca:
  # cambiarlo a «en_aduana» sería inventar un paso de aduana que no ocurrió.
  def sello_de_salto(caja, ahora)
    return {} unless salto?(caja)

    { salto_manifiesto_at: ahora, salto_manifiesto_por: @user&.iniciales_display,
      salto_manifiesto_estado: caja.estado }
  end

  def demasiadas_msg
    "Son más de #{Bulto::MAXIMO_POR_SESION} mediciones en una sola tanda. " \
      "Guardá e imprimí lo que llevás y seguí con la siguiente."
  end

  def sin_nada_msg
    "Una de las mediciones va sin números: poné al menos el peso, o las tres medidas."
  end

  def a_medias_msg
    "Las medidas van las tres —alto, largo y ancho— o ninguna. Con dos de tres no hay volumétrico."
  end

  def repetida_msg(caja)
    "#{codigo(caja)} está escaneada dos veces en la tanda: una caja se mide una sola vez."
  end

  def codigo(caja)
    caja.numero_recepcion_visible.presence || caja.tracking
  end
end
