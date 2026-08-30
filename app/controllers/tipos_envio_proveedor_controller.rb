# C21-08 · El tipo de envío DEL PROVEEDOR — «AEREO EXPRESS», «CKM MARITIMO».
#
# Sigue el patrón de `MotivosRetencionController`: el CRUD chico de un catálogo
# que el equipo del cliente mantiene solo. La diferencia es a dónde vuelve —al
# portal, con su solapa puesta— porque lo que Yusef pidió fue justamente no
# tener que andar buscando entre pantallas.
class TiposEnvioProveedorController < ApplicationController
  before_action :authorize_catalogos
  before_action :set_registro, only: %i[edit update]

  def new
    @registro = TipoEnvioProveedor.new
  end

  def create
    @registro = TipoEnvioProveedor.new(registro_params)
    if @registro.save
      redirect_to catalogos_manifiesto_path(tab: "tipos_proveedor"), notice: "Guardado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @registro.update(registro_params)
      redirect_to catalogos_manifiesto_path(tab: "tipos_proveedor"), notice: "Actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def authorize_catalogos
    # El mismo par que ya manda en /manifiestos y en /etiquetar: los tres
    # permisos de Miami van juntos, y separarlos acá haría que el link del
    # sidebar apareciera para gente que después choca con un redirect.
    require_role(:supervisor_miami, :digitador_miami)
  end

  def set_registro
    @registro = TipoEnvioProveedor.find(params[:id])
  end

  def registro_params
    params.require(:tipo_envio_proveedor).permit(:nombre, :position, :activo)
  end
end
