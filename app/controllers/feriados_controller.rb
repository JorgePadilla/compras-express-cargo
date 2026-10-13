# C31-11 · Los feriados con los que se cuenta la «posible fecha de entrega» en
# días hábiles.
#
# Jorge: *"Vamos a tener que hacer un portal para que vos metas los feriados."*
# Yusef: *"Sí… una vez ya quedan grabados. Bueno, se pueden modificar… porque
# cambian la semana morazánica, la semana santa."* Y en la prueba: *"Elimina el
# feriado y lo agrega"*. Por eso, a diferencia de los otros catálogos chicos,
# éste **sí** se borra: nada cuelga de un feriado, y uno que corrieron de fecha
# no tiene que quedar dando vueltas.
#
# Sigue el patrón de `MotivosRetencionController`. Un feriado cambiado no
# recalcula las fechas que ya se le dieron a los clientes: la fecha se fija al
# recibir (`Paquete#fijar_fecha_posible_entrega`), y lo que ya salió en un
# correo no se desdice solo (`RP-101`).
class FeriadosController < ApplicationController
  before_action :solo_admin
  before_action :set_feriado, only: %i[edit update destroy]

  def index
    @proximos = Feriado.desde_hoy.ordenados
    @pasados  = Feriado.where(fecha: ...Time.zone.today).order(fecha: :desc)
  end

  def new
    @feriado = Feriado.new
  end

  def create
    @feriado = Feriado.new(feriado_params)
    if @feriado.save
      redirect_to feriados_path, notice: "Feriado agregado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @feriado.update(feriado_params)
      redirect_to feriados_path, notice: "Feriado actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @feriado.destroy
    redirect_to feriados_path, notice: "Feriado eliminado."
  end

  private

  def set_feriado
    @feriado = Feriado.find(params[:id])
  end

  def feriado_params
    params.require(:feriado).permit(:fecha, :nombre)
  end

  # Va por `can_access?` y no por `require_admin`, como el resto de
  # Configuración: toda regla de rol pasa por `PermisosDelSistema`.
  def solo_admin
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless can_access?(:feriados)
  end
end
