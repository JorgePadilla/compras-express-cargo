# PR-F1.3 · Fase 15. El `EEE-PPP` de cada sucursal que factura. No tiene
# listado propio: se ven y se crean desde «Facturación SAR», al lado de sus CAI.
class PuntosDeEmisionController < ApplicationController
  before_action :solo_admin
  before_action :set_punto, only: %i[edit update]
  before_action :set_sucursales, only: %i[new create edit update]

  def new
    @punto = PuntoDeEmision.new(sucursal_id: params[:sucursal_id], activo: true)
  end

  def create
    @punto = PuntoDeEmision.new(punto_params)
    if @punto.save
      redirect_to autorizaciones_sar_path, notice: "Punto de emisión #{@punto.prefijo} creado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @punto.update(punto_params)
      redirect_to autorizaciones_sar_path, notice: "Punto de emisión #{@punto.prefijo} actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_punto
    @punto = PuntoDeEmision.find(params[:id])
  end

  # Las de Honduras que todavía no tienen punto, más la suya al editar.
  def set_sucursales
    tomadas = PuntoDeEmision.where.not(sucursal_id: @punto&.sucursal_id).select(:sucursal_id)
    @sucursales = Sucursal.activas.where(ubicacion: "honduras").where.not(id: tomadas).ordered
  end

  def punto_params
    params.require(:punto_de_emision).permit(:sucursal_id, :establecimiento, :punto, :activo)
  end

  # `RP-58` · La misma llave que la pantalla de la que cuelga.
  def solo_admin
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless can_access?(:autorizaciones_sar)
  end
end
