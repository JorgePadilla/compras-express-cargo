# PR-P.1 · Las líneas de un documento con las cajas **dentro** de su volumen.
#
# Una pre-factura por volumen (`ArmarPreFacturaPorVolumen`) lleva un renglón
# en L. 0.00 por cada caja de la tanda: es lo que hace que `confirmar!`,
# `facturar!` y `anular!` sigan encontrando sus paquetes. Pero un consolidado
# de cien cajas impreso así son cien renglones en cero. Esto los junta: cada
# línea sale como siempre, y después del **último** volumen de una tanda va la
# lista de sus cajas, una vez.
#
# Lo usan las cinco gemelas —pre-factura (ver y editar), factura, el PDF y la
# factura del portal del cliente—, y por eso es un objeto y no un helper: el
# PDF es Prawn y no ve los helpers. Sirve igual para `PreFacturaItem` y
# `VentaItem` (las dos llevan `bulto_id`), y con las líneas de las notas, que
# no lo llevan, no agrupa nada.
#
#   LineasPorVolumen.new(items).each do |linea, cajas|
#     # `cajas` viene vacía salvo después del último volumen de una tanda.
#   end
class LineasPorVolumen
  include Enumerable

  def initialize(items)
    @items = items.to_a
    precargar
  end

  def each
    return enum_for(:each) unless block_given?

    lineas.each { |linea| yield linea, cajas_despues_de(linea) }
  end

  # El código que se lee de una caja: el warehouse receipt, o el tracking.
  def self.codigo(item)
    paquete = item.paquete
    return item.concepto if paquete.nil?

    paquete.numero_recepcion_visible.presence || paquete.tracking
  end

  private

  def con_volumen? = @items.first.respond_to?(:bulto_id)

  # Una caja del volumen: colgada de un volumen y con su paquete. La línea que
  # cobra el volumen no tiene paquete.
  def caja?(item) = con_volumen? && item.bulto_id.present? && item.paquete_id.present?
  def volumen?(item) = con_volumen? && item.bulto_id.present? && item.paquete_id.nil?

  # Una caja cuyo volumen ya no está en el documento (alguien quitó la línea
  # con autorización) sale suelta, como cualquier línea: esconderla sería
  # esconder un paquete que el documento todavía cobra.
  def lineas = @lineas ||= @items.reject { |i| caja?(i) && sesiones_con_volumen.include?(i.bulto&.sesion) }

  def sesiones_con_volumen
    @sesiones_con_volumen ||= @items.select { |i| volumen?(i) }.map { |i| i.bulto&.sesion }.to_set
  end

  def cajas_despues_de(linea)
    return [] unless volumen?(linea)

    sesion = linea.bulto&.sesion
    return [] if ultimo_volumen_de[sesion] != linea

    cajas_por_sesion.fetch(sesion, [])
  end

  def ultimo_volumen_de
    @ultimo_volumen_de ||= @items.select { |i| volumen?(i) }.group_by { |i| i.bulto&.sesion }.transform_values(&:last)
  end

  def cajas_por_sesion
    @cajas_por_sesion ||= @items.select { |i| caja?(i) }.group_by { |i| i.bulto&.sesion }
  end

  # Sin esto, un consolidado de cien cajas son doscientas consultas: el lint
  # de `sin_n_mas_1_test` existe por pantallas así.
  def precargar
    return unless con_volumen? && @items.first.is_a?(ActiveRecord::Base)

    ActiveRecord::Associations::Preloader.new(records: @items, associations: [ :bulto, :paquete ]).call
  end
end
