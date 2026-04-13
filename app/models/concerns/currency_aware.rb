module CurrencyAware
  extend ActiveSupport::Concern

  MONEDAS = %w[LPS USD].freeze

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
