# PR-C6.29: la pantalla para cambiar la tasa de cambio.
#
# La tasa es el número que convierte cada precio en dólares a Lempiras, o sea
# que multiplica **todo** lo que se factura. Hasta ahora vivía solo en
# `db/seeds.rb` y en la consola: cero rutas, cero vistas la tocaban. Cambiarla
# requería un deploy.
#
# Yusef, 2026-08-02: "la tasa es **FIJA**, la fija un admin — no se jala del
# día". Por eso esto es un CRUD y no se reactiva
# `ActualizarTasaCambioJob`, que sigue deshabilitado en `config/recurring.yml`.
#
# Salió a la luz con sus respuestas del 2026-08-09: hizo la cuenta del mínimo
# de CER con **27.10** y el sistema tenía **24.85**. Con 24.85 sus números no
# dan — un CER de 1.5 lb caía en el mínimo (L.200) en vez de los L.210.37 que
# él calculó.
class TasaCambioController < ApplicationController
  CLAVE = "tasa_cambio".freeze

  before_action :require_admin

  def show
    @tasa = CurrencyAware.tasa_vigente
    @historial = PaperTrail::Version
                   .where(item_type: "Configuracion", item_id: registro&.id)
                   .order(created_at: :desc)
                   .limit(10)
    @ejemplo = ejemplo_de_cobro(@tasa)
  end

  def update
    nueva = params[:tasa_cambio].to_s.strip.tr(",", ".")

    if nueva.blank? || BigDecimal(nueva, exception: false).nil? || BigDecimal(nueva) <= 0
      redirect_to tasa_cambio_path, alert: "La tasa tiene que ser un número mayor que cero."
      return
    end

    Configuracion.set(CLAVE, BigDecimal(nueva).to_s("F"), tipo: "decimal", categoria: "moneda")
    redirect_to tasa_cambio_path,
                notice: "Tasa actualizada a #{BigDecimal(nueva).to_s('F')}. " \
                        "Aplica a todo lo que se cotice y facture de ahora en adelante."
  end

  private

  def require_admin
    redirect_to(root_path, alert: "Solo admin puede cambiar la tasa.") unless Current.user&.admin?
  end

  def registro
    @registro ||= Configuracion.find_by(clave: CLAVE)
  end

  # Un cobro real, calculado con el motor de verdad, para que el número no sea
  # abstracto. Es la misma cuenta que Yusef hizo a mano sobre el PDF:
  # 4.50 × 1.5 lb = $6.75 → × tasa → + ISV 15%.
  def ejemplo_de_cobro(tasa)
    tipo = TipoEnvio.activos.find_by(codigo: "cer")
    tarifa = tipo && Tarifa.resolver(tipo_envio: tipo, peso: 1.5)
    return nil if tarifa.nil?

    cobro = tarifa.cobro_para(1.5)
    neto = CurrencyAware.convertir(cobro[:subtotal], de: cobro[:moneda], a: "LPS", tasa: tasa)
    isv = Empresa.instance.isv_rate.to_d

    { neto: neto, total: (neto * (1 + isv)).round(2, BigDecimal::ROUND_HALF_UP),
      aplico_minimo: cobro[:aplico_minimo] }
  rescue StandardError
    nil
  end
end
