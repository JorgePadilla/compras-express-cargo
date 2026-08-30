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

  # «Terminar la recepción», con o sin faltantes. Marca lo que falta y cierra.
  def finalizar!(con_faltantes: false)
    faltantes = @manifiesto.cajas.where(recibida_at: nil).to_a
    return Resultado.new(recibidas: recibidas, faltantes: faltantes, paquetes: 0) if faltantes.any? && !con_faltantes

    paquetes = 0
    Manifiesto.transaction do
      if con_faltantes
        faltantes.each { |caja| caja.paquetes.each { |p| paquetes += 1 if mover_a_aduana(p) } }
      end
      @manifiesto.update!(estado: "recibido", fecha_aduana: @manifiesto.fecha_aduana || Time.current,
                          recepcion_finalizada_at: Time.current)
    end

    Resultado.new(recibidas: recibidas, faltantes: faltantes, paquetes: paquetes)
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
