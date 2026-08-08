module CurrencyAware
  extend ActiveSupport::Concern

  MONEDAS = %w[LPS USD].freeze

  # PR-10.a: la tasa como dato suelto, para quien necesita convertir sin ser
  # un documento con `moneda` propia (ej. `Tarifa`, que convierte el mínimo
  # de LPS a USD al comparar). Misma fuente y mismo fallback que
  # `#tasa_cambio_vigente`.
  #
  # Yusef 2026-08-02: la tasa es FIJA, la fija un admin — no se jala del día.
  def self.tasa_vigente
    Configuracion.get("tasa_cambio")&.to_d || BigDecimal("25.0")
  end

  # Convierte un monto entre LPS y USD a la tasa vigente.
  def self.convertir(monto, de:, a:, tasa: nil)
    monto = BigDecimal(monto.to_s)
    return monto if de == a

    tasa = (tasa || tasa_vigente).to_d
    return monto if tasa.zero?

    if de == "USD" && a == "LPS"
      (monto * tasa).round(2, BigDecimal::ROUND_HALF_UP)
    elsif de == "LPS" && a == "USD"
      (monto / tasa).round(2, BigDecimal::ROUND_HALF_UP)
    else
      monto
    end
  end

  included do
    validates :moneda, presence: true, inclusion: { in: MONEDAS }
    before_save :snapshot_tasa_cambio, if: :should_snapshot_tasa_cambio?
  end

  def tasa_cambio_vigente
    Configuracion.get("tasa_cambio")&.to_d || BigDecimal("25.0")
  end

  def convertir(monto, a:)
    monto = BigDecimal(monto.to_s)
    return monto if moneda == a

    if moneda == "USD" && a == "LPS"
      (monto * tasa_aplicada).round(2)
    elsif moneda == "LPS" && a == "USD"
      (monto / tasa_aplicada).round(2)
    else
      monto
    end
  end

  def simbolo_moneda
    moneda == "USD" ? "$" : "L."
  end

  private

  def tasa_aplicada
    tasa_cambio_aplicada&.to_d || tasa_cambio_vigente
  end

  def should_snapshot_tasa_cambio?
    tasa_cambio_aplicada.nil? || moneda_changed?
  end

  def snapshot_tasa_cambio
    self.tasa_cambio_aplicada = tasa_cambio_vigente
  end

  def moneda_changed?
    respond_to?(:will_save_change_to_moneda?) && will_save_change_to_moneda?
  end
end
