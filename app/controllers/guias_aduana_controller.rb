# C21-02 · Lo que llena San Pedro Sula, en su propia pantalla.
#
# Yusef, sobre la guía del proveedor: *"es editable… pero **no obligatorio**…
# lo ingresan después… le ingresa **la encargada de operaciones en San Pedro
# Sula**"*. Y sobre la fecha de aduana, que primero mandó a quitar y después
# rescató: *"esto de aduana, **aquí sí va**… es por la fecha de recibido en
# aduana en Honduras, o sea en aduana que es que **nosotros lo recibimos**"*.
#
# ── Por qué es una pantalla y no una sección del formulario ────────────────
#
# Jorge, 2026-08-30: *"hay que hacer dos accesos, links, iconos"*. Pero la razón
# de fondo la destapó el inventario: mientras los dos lados compartían el
# formulario del manifiesto, el recorte por rol era **100 % del controller** y
# la vista no se enteraba. San Pedro veía los campos de Miami habilitados, los
# editaba, apretaba Guardar, y el sistema **descartaba el cambio en silencio**
# contestándole «Manifiesto actualizado exitosamente».
#
# Acá no hay nada que recortar: la pantalla tiene dos campos y son los suyos.
class GuiasAduanaController < ApplicationController
  before_action :require_feature_access
  before_action :set_manifiesto, only: %i[edit update]

  # *"Solo le aparece lo que tiene que meter"* — la misma idea con la que Yusef
  # pidió la pantalla de recibir carga. Por defecto, lo que sigue esperando su
  # guía (la fecha de recibido ya no: la pone la recepción, C32-05); con
  # `?todos=1`, también lo ya completo, para poder corregir.
  def index
    @todos = params[:todos].present?
    # `A7-07` · `tipo_oficial`: los internos no cruzan aduana, así que no tienen
    # guía de proveedor ni fecha de aduana que llenar. También en la vista de
    # «todos», que si no los mostraría como pendientes eternos.
    base = Manifiesto.activos.tipo_oficial.includes(:empresa_manifiesto, :consignatario, :guias)
    base = base.where(estado: %w[enviado en_aduana recibido]) if @todos
    base = base.esperando_datos_de_san_pedro unless @todos

    # RP-87 · El badge dice «Terminado de Prefacturar»: una consulta para todos.
    @manifiestos = base.order(fecha_enviado: :desc).load
    Manifiesto.precargar_terminados(@manifiestos)
    @pendientes = Manifiesto.activos.esperando_datos_de_san_pedro.count
  end

  def edit
  end

  def update
    if @manifiesto.update(guias_aduana_params)
      redirect_to guias_aduana_index_path,
                  notice: "#{@manifiesto.numero}: guardado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def require_feature_access
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless can_access?(:guias_aduana)
  end

  def set_manifiesto
    @manifiesto = Manifiesto.find(params[:id])
  end

  # La lista blanca **es** `CAMPOS_DE_SAN_PEDRO`, derivada y no copiada: si
  # algún día San Pedro llena un campo más, se agrega en el modelo y esta
  # pantalla lo acepta sola.
  #
  # C32-05 · La fecha de recibido solo se acepta para **corregirla**: antes de
  # que la recepción la ponga, la pantalla no la muestra y un PATCH a mano
  # tampoco la escribe.
  def guias_aduana_params
    permitidos = params.require(:manifiesto)
                       .permit(:fecha_aduana, :fecha_posible_entrega, guias_attributes: %i[id numero position _destroy])
                       .slice(*Manifiesto::CAMPOS_DE_SAN_PEDRO)
    @manifiesto.fecha_aduana_corregible? ? permitidos : permitidos.except(:fecha_aduana)
  end
end
