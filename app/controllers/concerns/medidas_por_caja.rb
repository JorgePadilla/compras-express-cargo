# Peso y medidas propios de cada caja de un split, tal como los manda el
# partial compartido `shared/_peso_medidas_calc`.
#
# Llegan como `paquete[cajas][1][peso]`. Vive en un concern y no adentro de
# `EtiquetarController` porque el partial se usa en **dos** pantallas —
# `/etiquetar` y `/entrega_personal`— y las dos crean splits. Cuando esto
# vivía en una sola, Entrega Personal pintaba las filas y después las tiraba.
#
# Yusef pidió el peso por caja señalando el formulario: "acá sería cantidad de
# paquetes o productos, y aquí **el peso de cada quien**". Sin esto, un
# tracking con una caja de 5 lb y otra de 30 se factura como dos de 5 — o como
# dos de 30. Las dos están mal.
module MedidasPorCaja
  extend ActiveSupport::Concern

  # Lo que cambia de una caja a otra. El resto del paquete es el mismo para
  # todas: mismo tracking, mismo cliente, mismo servicio.
  #
  # `cantidad_productos` entró en `PR-C7.19`. Antes vivía en el bloque de
  # captura pero **no bajaba con la caja**, así que en un split las N cajas
  # terminaban con el mismo número —el último que quedara escrito— y el campo
  # seguía ahí, editable, pareciendo de la caja que se estaba midiendo. Jorge:
  # *"cambio la cantidad de productos y luego agrego… que se pueda cambiar
  # después de agregar cajas se siente raro"*.
  #
  # Encaja con cómo trabaja Yusef: *"recibo 30 cajas: 10 son de uno, 5 son de
  # otro"*. Y le da contenido a la columna **Units** del Warehouse Receipt, que
  # hasta ahora estaba escrita a mano como `1`.
  #
  # C20-12: la lista vive en `Paquete`, porque el modelo también la necesita
  # —al subir cajas, lo que es de cada caja NO se hereda de la caja 1—. Acá
  # queda el alias para quien ya la leía por este nombre.
  CAMPOS_POR_CAJA = Paquete::CAMPOS_POR_CAJA

  private

  def medidas_por_caja
    crudo = params.dig(:paquete, :cajas)
    return {} if crudo.blank?

    crudo.to_unsafe_h.each_with_object({}) do |(indice, valores), acc|
      # Un campo vacío no puede pisar con nil lo que ya trae el formulario:
      # el partial manda los cuatro inputs siempre, llenos o no.
      limpios = valores.slice(*CAMPOS_POR_CAJA).reject { |_k, v| v.to_s.strip.empty? }
      acc[indice.to_i] = limpios.symbolize_keys if limpios.any?
    end
  end
end
