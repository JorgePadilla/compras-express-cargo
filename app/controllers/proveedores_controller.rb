# PR-D3.a: CRUD admin del catálogo de proveedores + endpoint JSON para
# el autocomplete que se usa en el form del paquete (igual al patrón
# de `clientes#buscar`).
class ProveedoresController < ApplicationController
  before_action :solo_admin, except: [ :buscar ]
  before_action :set_proveedor, only: %i[edit update]

  def index
    @proveedores = Proveedor.ordered
  end

  def new
    @proveedor = Proveedor.new(activo: true, tipo: "comercio")
  end

  def create
    @proveedor = Proveedor.new(proveedor_params)
    if @proveedor.save
      redirect_to proveedores_path, notice: "Proveedor creado (#{@proveedor.codigo})."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @proveedor.update(proveedor_params)
      redirect_to proveedores_path, notice: "Proveedor actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Endpoint JSON para el Stimulus autocomplete del form de paquete.
  # Devuelve hasta 12 resultados activos que coinciden con el query.
  def buscar
    term = params[:q].to_s.strip
    @proveedores = Proveedor.activos.buscar(term).ordered.limit(12)
    render json: @proveedores.map { |p|
      { id: p.id, codigo: p.codigo, nombre: p.nombre, tipo: p.tipo }
    }
  end

  private


  def set_proveedor
    @proveedor = Proveedor.find(params[:id])
  end

  def proveedor_params
    params.require(:proveedor).permit(:nombre, :codigo, :tipo, :position, :activo, :notas)
  end
  # `RP-58` · Va por `can_access?` y no por `require_admin`: toda regla de rol
  # tiene que pasar por el mismo lugar, o una pantalla de permisos diría que se
  # puede algo que este controller después niega.
  def solo_admin
    redirect_to root_path, alert: "No tienes permiso para acceder a esta seccion." unless can_access?(:proveedores)
  end
end
