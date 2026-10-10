# Fase 15 · Facturación SAR (Acuerdo 481-2017). El espacio de nombres de los
# adaptadores de la gema `invoicehn` (F1.2: `Fiscal::Sequence`, `Fiscal::Store`,
# `Fiscal::Ledger`) y lo poco que comparten los modelos fiscales.
module Fiscal
  # D7 de FISCAL.md: la fecha fiscal es la de Honduras, siempre explícita. Hoy
  # `config.time_zone` («Central America») da lo mismo, pero una factura no
  # puede depender de que nadie toque esa línea.
  ZONA = "America/Tegucigalpa".freeze

  # El host de producción, el de `render.yaml`. Staging y producción corren las
  # dos con `RAILS_ENV=production`, así que `Rails.env` no las distingue.
  HOST_DE_PRODUCCION = "cec.comprasexpresscargo.com".freeze

  # Acuerdo 481-2017 Art. 10 num. 7 c), con los códigos de la reforma 609-2017.
  # Solo los que esta app emite.
  TIPOS_DE_DOCUMENTO = {
    "01" => "Factura",
    "06" => "Nota de Crédito",
    "07" => "Nota de Débito"
  }.freeze

  # El correlativo son 8 dígitos (Art. 10 num. 7 d).
  CORRELATIVO_MAXIMO = 99_999_999

  # Registro Tributario Nacional: 14 dígitos, sin dígito verificador publicado
  # (ver `Invoicehn::Rtn`). Guiones y espacios son costumbre de escritura.
  RTN = /\A\d{14}\z/

  def self.hoy
    Time.find_zone!(ZONA).today
  end

  # Ahí no se aceptan autorizaciones ficticias, y las ficticias que hubiera no
  # sirven para emitir (F1.2).
  def self.produccion?
    ENV["APP_HOST"] == HOST_DE_PRODUCCION
  end

  def self.normalizar_rtn(valor)
    valor.to_s.gsub(/[\s-]/, "").presence
  end
end
