# C21-08 · La empresa proveedora que mueve la carga — SERCARGO, PRONTO CARGO, GENESIS.
#
# Sigue el patrón de `MotivosRetencionController`: el CRUD chico de un catálogo
# que el equipo del cliente mantiene solo. La diferencia es a dónde vuelve —al
# portal, con su solapa puesta— porque lo que Yusef pidió fue justamente no
# tener que andar buscando entre pantallas.
class EmpresasManifiestoController < ApplicationController
  before_action :authorize_catalogos
  before_action :set_registro, only: %i[edit update]

  def new
    @registro = EmpresaManifiesto.new
  end

  def create
    @registro = EmpresaManifiesto.new(registro_params)
    if @registro.save
      redirect_to catalogos_manifiesto_path(tab: "empresas"), notice: "Guardado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @registro.update(registro_params)
      redirect_to catalogos_manifiesto_path(tab: "empresas"), notice: "Actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def authorize_catalogos
    # Miami y nada más. Se deriva de `Manifiesto::ROLES_DE_MIAMI` en vez de
    # escribirse cinco veces: esta misma línea estaba copiada en los cinco
    # controllers del portal, y `:manifiestos` —que era su llave— dejó de ser
    # solo de Miami cuando San Pedro entró a llenar la guía (`C21-02`).
    require_role(*Manifiesto::ROLES_DE_MIAMI)
  end

  def set_registro
    @registro = EmpresaManifiesto.find(params[:id])
  end

  def registro_params
    params.require(:empresa_manifiesto).permit(:nombre, :direccion, :telefono, :encargado, :activo)
  end
end
