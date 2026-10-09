# C19-06. Yusef: "¿vos no tenés en el sistema donde yo pueda cambiarlas yo?…
# a mí me habían dado esto [en el viejo] para no molestar… con eso yo te
# quito a vos". Las Dymo se van de lado con el uso ("le tuve que poner una
# tuerca"), así que los márgenes horizontales de la etiqueta son ajustables
# por admin desde /ajustes_etiqueta — claves en Configuracion, sin migración.
#
# El tope de 10mm es una red: la etiqueta mide 57mm de ancho (2.25in) y un
# margen tecleado de más dejaría los trackings sin lugar — y "LOS TRACKING
# DEBEN CABER COMPLETOS" es regla escrita de Yusef. Un valor fuera de rango
# cae al default en vez de imprimirse.
module EtiquetaAjustes
  CLAVE_IZQ = "etiqueta_margen_izq_mm".freeze
  CLAVE_DER = "etiqueta_margen_der_mm".freeze

  # C19-06 los dejó en 2.5/1.5: "correr este lado, del lado izquierdo hacia la
  # derecha; el lado derecho déjalo tal cual".
  #
  # C20-03 los devuelve a 1.5 parejo, que era el valor histórico, y la vuelta
  # atrás es deliberada. Ese milímetro compensaba la deriva de UNA impresora
  # —"en San Pedro le tuve que poner una tuerca"— y desde C19-06 eso se ajusta
  # desde la pantalla, sin deploy: no tiene por qué ser el default de todas.
  # Peor: el ancho que le quitaba era justo el que le faltaba al código de
  # barras para no cortarse (C20-02).
  #
  # Y el piso no es cero: el margen ES la zona muda del Code 128. Un barcode
  # pegado al borde tampoco se lee, aunque esté completo — por eso restablecer
  # cae a 1.5/1.5 y no a 0.
  IZQ_DEFAULT_MM = 1.5
  DER_DEFAULT_MM = 1.5
  MAX_MM = 10

  def self.margen_izq_mm
    leer(CLAVE_IZQ, IZQ_DEFAULT_MM)
  end

  def self.margen_der_mm
    leer(CLAVE_DER, DER_DEFAULT_MM)
  end

  def self.leer(clave, default)
    valor = BigDecimal(Configuracion.get(clave).to_s, exception: false)
    return default if valor.nil? || valor.negative? || valor > MAX_MM

    valor.to_f
  end
  private_class_method :leer
end
