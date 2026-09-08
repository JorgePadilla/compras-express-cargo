# C26-19 · Guardar las mediciones de una sesión: los bultos que el operario armó
# en la mesa, con sus números, y el sello en cada caja.
#
# Todo entra junto, como las cajas de /etiquetar (`A7-21`: *"cuando menos
# acordás me salieron cuatro en vez de cinco"*): al imprimir ya se sabe cuántas
# mediciones son, y eso es lo que dice el «1 de 2» del QR.
#
# Reemplaza a `MedirPaquete` para el camino nuevo. `MedirPaquete` sigue vivo
# porque un bulto de una sola caja no es un caso especial: es el mismo servicio
# con una caja adentro.
class MedirBulto
  class NoSePuede < StandardError; end

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

  # `mediciones` es una lista de `{ paquete_ids: [...], peso:, alto:, largo:,
  # ancho: }`, en el orden en que el operario las fue agregando.
  def guardar!(mediciones)
    lista = Array(mediciones).map { |m| m.respond_to?(:to_unsafe_h) ? m.to_unsafe_h : m.to_h }
    raise NoSePuede, "No hay ninguna medición que guardar." if lista.empty?
    raise NoSePuede, demasiadas_msg if lista.size > Bulto::MAXIMO_POR_SESION

    cajas_por_medicion = lista.map { |m| cajas_de(m) }
    numeros_por_medicion = lista.map { |m| numeros_de(m) }
    reemplazos = lista.map { |m| reemplazo_de(m) }
    validar!(cajas_por_medicion, reemplazos)

    sesion = SecureRandom.uuid
    ahora = Time.current

    Bulto.transaction do
      cajas_por_medicion.each_with_index.map do |cajas, i|
        nuevo = crear!(cajas, numeros_por_medicion[i], sesion: sesion, orden: i + 1,
                       de_cuantos: lista.size, ahora: ahora)
        reemplazar!(reemplazos[i], cajas) if reemplazos[i]
        nuevo
      end
    end
  end

  private

  def crear!(cajas, numeros, sesion:, orden:, de_cuantos:, ahora:)
    bulto = Bulto.create!(cliente: cajas.first.cliente, user: @user, sesion: sesion,
                          orden: orden, de_cuantos: de_cuantos, medido_at: ahora,
                          medido_por: @user&.iniciales_display, **numeros)
    # A la caja **solo** el vínculo y el sello. Sus `peso, alto, largo, ancho`
    # son el dato de Miami y no se pisan: el que cobra es el bulto.
    cajas.each do |caja|
      caja.update!(bulto: bulto, medido_at: ahora, medido_por: @user&.iniciales_display,
                   **sello_de_salto(caja, ahora))
    end
    # El `peso_cobrar` se calcula con las cajas ya atadas: el trato de cobro del
    # cliente se lee de ellas.
    bulto.paquetes.reset
    bulto.save!
    bulto
  end

  # C27-33 · Medir de nuevo: el bulto viejo se va y el nuevo ocupa su lugar.
  # Sus cajas ya apuntan al nuevo (`crear!`); las que el operario **sacó de la
  # mesa** vuelven a estar sin medir —y a la lista de pendientes—, porque el
  # único número que tenían era el del bulto que acaba de morir. `has_paper_trail`
  # en `Bulto` guarda los números viejos con quién los puso.
  def reemplazar!(viejo, cajas_nuevas)
    ids = cajas_nuevas.map(&:id)
    viejo.paquetes.where.not(id: ids).find_each do |caja|
      caja.update!(bulto: nil, medido_at: nil, medido_por: nil)
    end
    viejo.destroy!
  end

  def reemplazo_de(medicion)
    id = (medicion[:reemplaza_bulto_id] || medicion["reemplaza_bulto_id"]).to_i
    return nil if id.zero?

    Bulto.find_by(id: id) or raise NoSePuede, "El bulto que se quería corregir ya no existe. Escaneá la caja otra vez."
  end

  def cajas_de(medicion)
    ids = Array(medicion[:paquete_ids] || medicion["paquete_ids"]).map(&:to_i).uniq
    raise NoSePuede, "Una de las mediciones no tiene ninguna caja escaneada." if ids.empty?

    cajas = Paquete.where(id: ids).includes(:cliente, :tipo_envio).to_a
    raise NoSePuede, "Alguna de las cajas escaneadas ya no existe." if cajas.size != ids.size

    cajas
  end

  # La misma regla que `MedirPaquete`: al menos uno de los cuatro, y las tres
  # medidas van juntas o no van.
  def numeros_de(medicion)
    valores = MedirPaquete::CAMPOS.index_with { |c| medicion[c] || medicion[c.to_s] }
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
  # «NO Mezclar» sobre toda la sesión, no solo dentro de cada medición: dos
  # bultos de la misma mesa son del mismo cliente y del mismo servicio.
  def validar!(cajas_por_medicion, reemplazos = [])
    todas = cajas_por_medicion.flatten
    repetida = todas.group_by(&:id).find { |_id, v| v.size > 1 }
    raise NoSePuede, repetida_msg(repetida.last.first) if repetida

    cajas_por_medicion.each_with_index do |cajas, i|
      cajas.each { |caja| validar_caja!(caja, reemplaza: reemplazos[i]) }
    end

    todas.each_with_index do |caja, i|
      next if i.zero?

      problema = PuedenIrJuntas.new(todas.first(i), caja).problema
      raise NoSePuede, problema.mensaje if problema
    end
  end

  def validar_caja!(caja, reemplaza: nil)
    if caja.pre_factura_id.present? || caja.venta_id.present?
      raise NoSePuede, "#{codigo(caja)} ya está en una pre-factura: el peso se congeló ahí."
    end
    # Una caja que ya tiene bulto solo entra si esta medición viene a
    # reemplazar **ese** bulto: si no, es un pip sobre una caja ya medida y la
    # pantalla tiene que haber preguntado antes.
    if caja.bulto_id.present? && caja.bulto_id != reemplaza&.id
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
    "#{codigo(caja)} está en dos mediciones: una caja se mide una sola vez."
  end

  def codigo(caja)
    caja.numero_recepcion_visible.presence || caja.tracking
  end
end
