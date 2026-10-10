# Fase 15 · Facturación SAR (Acuerdo 481-2017). El espacio de nombres de los
# adaptadores de la gema `invoicehn` (F1.2: `Fiscal::Sequence`, `Fiscal::Store`,
# `Fiscal::Ledger`) y lo poco que comparten los modelos fiscales.
module Fiscal
  # D7 de FISCAL.md: la fecha fiscal es la de Honduras, siempre explícita. Hoy
  # `config.time_zone` («Central America») da lo mismo, pero una factura no
  # puede depender de que nadie toque esa línea.
  ZONA = "America/Tegucigalpa".freeze

  # Los hosts de `render.yaml`. Staging y producción corren las dos con
  # `RAILS_ENV=production`, así que `Rails.env` no las distingue.
  HOST_DE_PRODUCCION = "cec.comprasexpresscargo.com".freeze
  HOST_DE_STAGING = "cec-staging.onrender.com".freeze

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

  # ── PR-F2.2a · Por qué una factura no sale ────────────────────────────
  # Con nombre propio, para que la pantalla de F2.4 los muestre sin adivinar.
  # Ninguno consume número: todos saltan antes del correlativo o adentro de su
  # bloque, que se deshace.
  class EmisionRechazada < StandardError; end

  # Jorge (Q5): quien factura tiene que tener sucursal, y la sucursal un punto
  # de emisión activo (D9).
  class SinPuntoDeEmision < EmisionRechazada; end

  # La gema sumó otra cosa que las pre-facturas. Un tripwire: F2.1 prueba la
  # equivalencia, así que no tendría que pasar nunca; si pasa, no se factura.
  class TotalesNoCuadran < EmisionRechazada; end

  # Una línea sin concepto (Art. 11 num. 1 lit. d), pre-facturas que no van
  # juntas, o que ya se facturaron.
  class PreFacturasNoFacturables < EmisionRechazada; end

  # La anulación no procede: sin motivo, con pagos, con PIN o autorizante que
  # no sirven, o ya anulada.
  class AnulacionRechazada < StandardError; end

  def self.hoy
    Time.find_zone!(ZONA).today
  end

  # Ahí no se aceptan autorizaciones ficticias, y las ficticias que hubiera no
  # sirven para emitir (F1.2).
  #
  # QA de PR-F1.1 · **Falla cerrado**: con `RAILS_ENV=production`, es
  # producción salvo que el host sea, exacto, el de staging. Preguntar
  # «¿es el host de producción?» fallaba abierto: hoy producción contesta en
  # `cec-production.onrender.com` (el dominio de `render.yaml` no responde), y
  # Render ya no sincroniza el blueprint, así que el `APP_HOST` real puede no
  # ser el del yaml. Con un host distinto, la ficticia habría entrado en
  # producción sin ruido. Al revés, un staging mal configurado rechaza su
  # ficticia con un error a la vista, que es la falla barata.
  def self.produccion?
    Rails.env.production? && ENV["APP_HOST"] != HOST_DE_STAGING
  end

  def self.normalizar_rtn(valor)
    valor.to_s.gsub(/[\s-]/, "").presence
  end

  # PR-F1.2 · La emisión con la gema, armada con los adaptadores de Postgres.
  # `punto` decide la dirección del establecimiento en el emisor; el número lo
  # decide el `identifier:` que se le pasa a `#issue` (`punto.identificador`).
  # `borrador` es el registro de negocio que se estampa con el número (ver
  # `Fiscal::Store`); sin él, el documento se guarda igual.
  def self.issuance(punto:, borrador: nil)
    Invoicehn::Issuance.new(store: Store.new(punto: punto, borrador: borrador),
                            sequence: Sequence.new, ledger: Ledger.new)
  end

  # "EEE-PPP-TT" → [PuntoDeEmision, "TT"]. La gema habla en identificadores;
  # las tablas, en punto y tipo.
  def self.punto_y_tipo(identificador)
    establecimiento, punto, tipo = identificador.to_s.split("-")
    unless TIPOS_DE_DOCUMENTO.key?(tipo)
      raise Invoicehn::ValidationError, "tipo de documento que no se emite: #{identificador.inspect}"
    end

    punto_de_emision = PuntoDeEmision.find_by(establecimiento: establecimiento, punto: punto)
    raise Invoicehn::ValidationError, "no hay punto de emisión #{establecimiento}-#{punto}" unless punto_de_emision

    [ punto_de_emision, tipo ]
  end
end
