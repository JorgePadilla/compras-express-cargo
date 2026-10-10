# C30-09 · «6 de 7 · falta 1»: cuánto va recibido de un manifiesto y qué falta.
#
# Yusef, en /recibir-carga con cinco manifiestos a la vez:
#
#   > "Algo como lo que hiciste de medición, algo que te vaya diciendo **cuál
#   >  quedó pendiente**… si 7 cajas iban 6 nada más, **falta una**."
#
# Lo leen tres lugares —la fila de la lista, la respuesta de la pistola de la
# lista y la de la pistola del manifiesto— y tienen que decir lo mismo, así
# que la cuenta vive acá una sola vez.
#
# Se cuenta en la **unidad del manifiesto**, igual que `aviso_de_faltantes` del
# controller: cajas en el oficial (`A7-06`, *"no escanean los paquetes, solo
# escanean las cajas"*) y paquetes en el interno (`A7-08`).
#
# **Lee las asociaciones como estén cargadas.** La lista le pasa manifiestos con
# `includes(:cajas, :paquetes)` y acá se cuenta en memoria: un `where` por fila
# es justo lo que `sin_n_mas_1_test` caza en /recepcion_carga.
class ProgresoDeRecepcion
  attr_reader :manifiesto

  def initialize(manifiesto)
    @manifiesto = manifiesto
  end

  def unidad = manifiesto.tipo_interno? ? "paquetes" : "cajas"

  def total = unidades.size

  def recibidas = total - pendientes.size

  # Lo que falta, con el nombre que se lee en la etiqueta: la letra de la caja
  # (`B`), o el tracking del paquete en el interno.
  def faltantes
    if manifiesto.tipo_interno?
      pendientes.map(&:tracking)
    else
      pendientes.sort_by { |c| CajaManifiesto.numero_para(c.letra) || 0 }.map(&:letra)
    end
  end

  def completo? = total.positive? && pendientes.empty?

  # C21-01 · Los que viajaron sin caja, del camino sin escaneo. No se escanean:
  # pasan a aduana al terminar. Se cuentan para que la fila no diga «0 de 0»
  # sobre un manifiesto lleno de carga.
  def sin_caja
    return 0 if manifiesto.tipo_interno?

    manifiesto.paquetes.count { |p| p.caja_manifiesto_id.nil? }
  end

  def texto
    return sin_unidades if total.zero?

    base = "#{recibidas} de #{total}"
    completo? ? "#{base} · completo" : "#{base} · falta #{pendientes.size}"
  end

  def to_h
    { id: manifiesto.id, numero: manifiesto.numero, unidad: unidad,
      recibidas: recibidas, total: total, faltantes: faltantes,
      completo: completo?, texto: texto }
  end

  private

  def unidades
    @unidades ||= manifiesto.tipo_interno? ? manifiesto.paquetes.to_a : manifiesto.cajas.to_a
  end

  # En el interno, «recibido» es haber salido de `enviado_sucursal`: el paquete
  # se mueve al escanearlo (`RecibirManifiesto#recibir_paquete!`).
  def pendientes
    return @pendientes if defined?(@pendientes)

    @pendientes = if manifiesto.tipo_interno?
      unidades.select { |p| p.estado == "enviado_sucursal" }
    else
      unidades.reject(&:recibida_at)
    end
  end

  def sin_unidades
    n = sin_caja
    n.positive? ? "sin cajas · #{n} paquete#{"s" unless n == 1} pasan al terminar" : "sin carga"
  end
end
