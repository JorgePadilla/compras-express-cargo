# PR-F1.3 · Fase 15. «Facturación SAR»: los puntos de emisión de cada sucursal
# y las autorizaciones (CAI) con su rango y su fecha límite.
#
# Jorge, 2026-10-10: *sin CAI real todavía; pantalla admin para cargar CAIs y
# rangos*. Las reglas viven en `AutorizacionSar` (rango sin pisarse, arriba de
# lo emitido, intocable con documentos); acá solo se cargan y se muestran.
#
# La pantalla **no** ofrece `ficticia`: el CAI inventado de staging lo siembra
# la migración de F1.5, y un CAI cargado a mano es siempre uno real.
class AutorizacionesSarController < ApplicationController
  before_action :solo_admin
  before_action :set_autorizacion, only: %i[show edit update]
  before_action :no_si_ya_se_emitio, only: %i[edit update]
  before_action :set_puntos, only: %i[new create edit update]

  def index
    @puntos = PuntoDeEmision.includes(:sucursal).order(:establecimiento, :punto)
    @sucursales_sin_punto = Sucursal.activas.where(ubicacion: "honduras")
                                    .where.missing(:punto_de_emision).ordered
    @autorizaciones = AutorizacionSar.includes(punto_de_emision: :sucursal)
                                     .order(:punto_de_emision_id, :tipo_documento, rango_inicio: :desc)
    # El último emitido por punto y tipo, de una vez: la columna «Usados».
    @ultimos = CorrelativoFiscal.pluck(:punto_de_emision_id, :tipo_documento, :ultimo)
                                .to_h { |punto, tipo, ultimo| [ [ punto, tipo ], ultimo ] }
  end

  def show
  end

  def new
    @autorizacion = AutorizacionSar.new(tipo_documento: "01", punto_de_emision_id: params[:punto_de_emision_id])
  end

  def create
    @autorizacion = AutorizacionSar.new(autorizacion_params.merge(cargada_por: Current.user))
    if @autorizacion.save
      # TODO(PR-F1.2): `Fiscal::Sequence#align_to(@autorizacion)` — si el
      # correlativo está por debajo de `rango_inicio - 1`, subirlo, para que el
      # primer número emitido sea el primero del rango. Va con la gema.
      redirect_to autorizacion_sar_path(@autorizacion), notice: "Autorización cargada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @autorizacion.update(autorizacion_params)
      redirect_to autorizacion_sar_path(@autorizacion), notice: "Autorización actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_autorizacion
    @autorizacion = AutorizacionSar.find(params[:id])
  end

  # Los activos, y el que ya tenga la autorización aunque se haya desactivado:
  # si no, el formulario de editar le cambiaría el punto sin que nadie lo pida.
  def set_puntos
    @puntos = PuntoDeEmision.where(activo: true).or(PuntoDeEmision.where(id: @autorizacion&.punto_de_emision_id))
                            .includes(:sucursal).order(:establecimiento, :punto)
  end

  # Sin `ficticia` ni `cargada_por`: no se cargan desde el formulario.
  def autorizacion_params
    params.require(:autorizacion_sar).permit(:punto_de_emision_id, :tipo_documento, :cai,
                                             :rango_inicio, :rango_fin,
                                             :fecha_autorizacion, :fecha_limite_emision)
  end

  # El modelo ya lo rechaza; esto evita mostrar un formulario que no se va a
  # poder guardar.
  def no_si_ya_se_emitio
    return unless @autorizacion.documentos_emitidos?

    redirect_to autorizacion_sar_path(@autorizacion),
                alert: "Ya se emitieron documentos con esta autorización: no se puede cambiar."
  end

  # `RP-58` · Por `can_access?`, como el resto de Configuración.
  def solo_admin
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless can_access?(:autorizaciones_sar)
  end
end
