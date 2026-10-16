# C32-01 · El historial de manifiestos. Yusef, mostrando el del sistema viejo
# en la prueba del 2026-10-14: *"aquí está el historial del año… acá tiene la
# fecha de creado, fecha de enviado y fecha que van"* · *"esto sí lo ocupamos
# así, para nosotros tener una información más inclusiva"*.
#
# Jorge, 2026-10-15: *"va a ser una nueva sección con filtros"* — para buscar
# **todos** los manifiestos por un tiempo. `/manifiestos` sigue siendo la
# pantalla de trabajo de Miami; esta es solo de consulta: no se arma ni se
# edita nada desde acá.
#
# Los filtros, con sus palabras:
# - Estados con casillas, de a varios: *"haces el de cheque, porque yo ocupo
#   marcar cuáles están enviados, cuáles están en aduana; a veces quiero saber
#   recibido y aduana"*. Al entrar vienen **todos** marcados (Jorge,
#   2026-10-15). «Terminado de Prefacturar» es uno más: el manifiesto que ya
#   terminó sale ahí y no en «Recibido».
# - Empresa y tipo de envío: *"con qué empresa, qué tipo de envío"*.
# - El buscador exacto (`Manifiesto.buscar_exacto`).
# - La ventana de «Todos los paquetes» (`PaquetesController#base_scope`):
#   *"solo nos incluía hasta tres meses; si yo quiero ver de tres meses a doce,
#   le doy click, y si quiero ver de más de doce meses, le doy a tanto"*. O un
#   desde / hasta, que manda sobre la ventana.
class HistorialManifiestosController < ApplicationController
  before_action :require_feature_access

  ESTADOS = [
    [ "creado", "Creado" ],
    [ "enviado", "Enviado" ],
    [ "en_aduana", "En aduana" ],
    [ "recibido", "Recibido" ],
    [ "terminado", Manifiesto::TERMINADO_DE_PREFACTURAR ]
  ].freeze

  def index
    @estados = estados_marcados
    @empresas = EmpresaManifiesto.activos.order(:nombre)
    @tipo_envios = TipoEnvio.activos.order(:nombre)

    @manifiestos = filtrar(Manifiesto.activos)
                     .includes(:empresa_manifiesto, :tipo_envios, :sucursales_entrega, :sucursal_entrega, :guias)
                     .order(created_at: :desc)
                     .page(params[:page]).per(per_page_sanitized).load
    Manifiesto.precargar_terminados(@manifiestos)
    @inicio_de_prefactura = Manifiesto.inicio_de_prefactura_por_id(@manifiestos.map(&:id))
  end

  private

  def require_feature_access
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless can_access?(:historial_manifiestos)
  end

  # Sin el parámetro, todos: es como se entra. Desmarcarlos todos es lo mismo
  # que no filtrar — un historial vacío por no tener nada marcado no le sirve
  # a nadie.
  def estados_marcados
    elegidos = Array(params[:estados]).compact_blank & ESTADOS.map(&:first)
    elegidos.presence || ESTADOS.map(&:first)
  end

  def filtrar(scope)
    scope = por_estado(scope)
    scope = scope.buscar_exacto(params[:q]) if params[:q].present?
    scope = scope.where(empresa_manifiesto_id: params[:empresa_manifiesto_id]) if params[:empresa_manifiesto_id].present?
    scope = scope.where(tipo: params[:tipo]) if params[:tipo].in?(Manifiesto.tipos.keys)
    tipos = Array(params[:tipo_envio_ids]).compact_blank
    scope = scope.where(id: ManifiestoTipoEnvio.where(tipo_envio_id: tipos).select(:manifiesto_id)) if tipos.any?
    por_fecha(scope)
  end

  # «Terminado de Prefacturar» se deriva (`Manifiesto.terminados_de_prefacturar`):
  # el que terminó **no** sale en «Recibido» o «En aduana», sale en la suya.
  def por_estado(scope)
    return scope if @estados.size == ESTADOS.size

    terminados = Manifiesto.terminados_de_prefacturar.select(:id)
    guardados = @estados - [ "terminado" ]
    condicion = scope.where(estado: guardados).where.not(id: terminados)
    condicion = condicion.or(scope.where(id: terminados)) if @estados.include?("terminado")
    condicion
  end

  # Desde / hasta manda; si no hay, la ventana de «Todos los paquetes», que es
  # acumulativa: «3–12 meses» trae el último año y «más de 1 año», todo.
  def por_fecha(scope)
    desde = fecha(params[:desde])
    hasta = fecha(params[:hasta])
    if desde || hasta
      scope = scope.where(created_at: desde.beginning_of_day..) if desde
      scope = scope.where(created_at: ..hasta.end_of_day) if hasta
      return scope
    end

    if params[:incluir_mas_1_ano] == "1" then scope
    elsif params[:incluir_3_12_meses] == "1" then scope.where(created_at: 1.year.ago..)
    else scope.where(created_at: 3.months.ago..)
    end
  end

  def fecha(valor)
    Date.iso8601(valor.to_s) if valor.present?
  rescue Date::Error
    nil
  end
end
