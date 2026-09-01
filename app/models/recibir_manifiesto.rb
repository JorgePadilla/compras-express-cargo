# C21-07 · Recibir la carga: las cajas escaneadas pasan sus paquetes a aduana.
#
# La regla la fijó Yusef en la Conversación 7 y la ratificó en la 21: **no
# bloquea**. Jorge le preguntó justamente eso —*"dependiendo qué tan dura querés
# esa regla… puede llegar a convertirse en un problema en el proceso"*— y él
# contestó *"que no lo bloquee"*. Al finalizar:
#
#   > "Le va a decir: **falta la 2 de 3, falta la 8 de 10**… y te tira un
#   >  listado."
#   > "Te va a dar la opción: seguir escaneando o **marcar como recibido con las
#   >  pendientes**."
#
# Y de la 21: *"a veces no viene todo… hay que marcar todo como que está acá.
# Pero todavía le pone una opción de marcar todo el manifiesto"*.
class RecibirManifiesto
  Resultado = Struct.new(:recibidas, :faltantes, :paquetes, keyword_init: true)

  def initialize(manifiesto, user: nil)
    @manifiesto = manifiesto
    @user = user
  end

  # Una caja escaneada. Sus paquetes pasan a aduana en el acto: *"en el instante
  # en que se están recibiendo, todos los paquetes que vienen amarrados en ese
  # manifiesto van marcándose como aduana"* (`A7-04`).
  def recibir_caja!(caja)
    CajaManifiesto.transaction do
      caja.update!(recibida_at: Time.current, recibida_por_id: @user&.id)
      caja.paquetes.each { |paquete| mover_a_aduana(paquete) }
      # El manifiesto queda «en aduana» mientras se recibe: parcial es un estado
      # legítimo, no un error.
      @manifiesto.update!(estado: "en_aduana") if @manifiesto.enviado?
    end
  end

  # `A7-08` · En el **interno** se escanean paquetes, no cajas.
  #
  # Yusef, describiendo lo que ya hacen: *"yo veo que escanean el manifiesto y
  # empiezan a **escanear paquete por paquete** para cuadrar el manifiesto"*. El
  # interno lleva carga suelta, no casas armadas.
  #
  # «Escaneado» no necesita columna nueva: el paquete **se mueve al escanearlo**,
  # igual que en el oficial una caja mueve a los suyos en el acto. Lo que no se
  # escaneó se reconoce solo, porque sigue en `enviado_sucursal`.
  #
  # Y a dónde va: `disponible_entrega` **en la sucursal destino**. La carga llegó
  # a donde el cliente la retira, que es lo que `A7-13` pide que se le muestre —
  # *"Disponible en sucursal Tegucigalpa"*.
  def recibir_paquete!(paquete)
    Paquete.transaction do
      paquete.update!(estado: "disponible_entrega",
                      sucursal_actual: @manifiesto.sucursal_entrega)
      @manifiesto.update!(estado: "en_aduana") if @manifiesto.enviado?
    end
  end

  # Los que el manifiesto interno trajo y todavía nadie escaneó.
  def paquetes_pendientes
    @manifiesto.paquetes.where(estado: "enviado_sucursal")
  end

  # «Terminar la recepción», con o sin faltantes. Marca lo que falta y cierra.
  #
  # C21-01 · **Al cerrar se barre el manifiesto entero, no solo las cajas.**
  # Yusef dejó dos caminos vivos a propósito: el nuevo —crear el manifiesto,
  # sacar las pre-etiquetas de los bultos y escanear cada paquete adentro— y el
  # de siempre, *"que es lo que está actualmente"*, que se queda *"porque a
  # veces no da tiempo"*: se le meten los paquetes al manifiesto derecho, sin
  # cajas y sin pistola.
  #
  # Este método solo miraba `caja.paquetes`. Un manifiesto armado por el camino
  # viejo llega a Honduras **sin una sola caja**, así que la pantalla decía
  # «0 de 0 recibidas», «Terminar» salía bien, el manifiesto quedaba `recibido`
  # — y sus paquetes se quedaban en `enviado_honduras` para siempre. No llegaban
  # a aduana, y por lo tanto tampoco a la pre-factura.
  #
  # Peor que un hueco: quedaba **inconsistente y callado**, con el manifiesto
  # diciendo una cosa y sus paquetes otra.
  def finalizar!(con_faltantes: false)
    return finalizar_interno!(con_faltantes: con_faltantes) if @manifiesto.tipo_interno?

    faltantes = @manifiesto.cajas.where(recibida_at: nil).to_a
    return Resultado.new(recibidas: recibidas, faltantes: faltantes, paquetes: 0) if faltantes.any? && !con_faltantes

    paquetes = 0
    Manifiesto.transaction do
      pendientes = con_faltantes ? @manifiesto.paquetes : paquetes_sin_caja
      pendientes.each { |p| paquetes += 1 if mover_a_aduana(p) }

      @manifiesto.update!(estado: "recibido", fecha_aduana: @manifiesto.fecha_aduana || Time.current,
                          recepcion_finalizada_at: Time.current)
    end

    Resultado.new(recibidas: recibidas, faltantes: faltantes, paquetes: paquetes)
  end

  # `A7-09` · Cerrar el **interno**, y acá hay una diferencia de fondo con el
  # oficial que vale escribir, porque la forma obvia sería copiarlo y estaría mal.
  #
  # El oficial, al cerrar «con faltantes», **mueve igual todos** los paquetes a
  # aduana: la caja que no apareció ya está perdida y no cerrar no la trae.
  #
  # En el interno **el que no se escaneó se queda en `enviado_sucursal`**, y eso
  # es justamente el producto: *"¿por qué va a servir ese status nuevo? Porque
  # esto sirve de auditoría. Qué paquete no escanearon o no enviaron… ey, este
  # sale pendiente, hay que buscarlo"* (`A7-09`).
  #
  # Marcarlo `disponible_entrega` sería **decirle al cliente que venga a retirar
  # algo que no llegó**. El manifiesto se cierra; el paquete queda señalado.
  def finalizar_interno!(con_faltantes: false)
    faltantes = paquetes_pendientes.to_a
    return Resultado.new(recibidas: [], faltantes: faltantes, paquetes: 0) if faltantes.any? && !con_faltantes

    recibidos = @manifiesto.paquetes.where(estado: "disponible_entrega").count

    @manifiesto.update!(estado: "recibido", recepcion_finalizada_at: Time.current)

    Resultado.new(recibidas: [], faltantes: faltantes, paquetes: recibidos)
  end

  # Los que viajaron sin caja: el camino sin escaneo. Se cuentan aparte para que
  # la pantalla pueda decir cuántos son en vez de mostrar una tabla vacía.
  def paquetes_sin_caja
    @manifiesto.paquetes.where(caja_manifiesto_id: nil)
  end

  def recibidas = @manifiesto.cajas.where.not(recibida_at: nil).to_a

  private

  # `en_aduana` no tenía **ni un solo escritor** en todo el sistema: el único
  # camino era el dropdown de la ficha del paquete, uno por uno. Ese es el hueco.
  def mover_a_aduana(paquete)
    return false if paquete.en_aduana?

    paquete.update(estado: "en_aduana")
  end
end
