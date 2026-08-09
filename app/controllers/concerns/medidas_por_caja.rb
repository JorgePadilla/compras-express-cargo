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

  # Solo estos cuatro. El resto del paquete es el mismo para todas las cajas:
  # mismo tracking, mismo cliente, mismo contenido. Lo único que cambia
  # físicamente es cuánto pesa y mide cada bulto.
  CAMPOS_POR_CAJA = %w[peso alto largo ancho].freeze

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
