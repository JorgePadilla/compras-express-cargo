class ClientesController < ApplicationController
  before_action :set_cliente, only: [ :show, :edit, :update ]
  before_action :authorize_buscar, only: [ :buscar ]

  def index
    @clientes = Cliente.activos.includes(:categoria_precio).order(created_at: :desc)
    @clientes = @clientes.buscar(params[:q]) if params[:q].present?
    @clientes = @clientes.page(params[:page]).per(25)
  end

  def show
  end

  def new
    @cliente = Cliente.new
  end

  def create
    @cliente = Cliente.new(cliente_params)
    if @cliente.save
      redirect_to @cliente, notice: "Cliente creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def buscar
    clientes = Cliente.activos.buscar(params[:q]).includes(:categoria_precio).limit(10)
    render json: clientes.map { |c|
      {
        id: c.id,
        codigo: ERB::Util.html_escape(c.codigo),
        nombre: ERB::Util.html_escape(c.nombre_completo),
        notas_miami: ERB::Util.html_escape(c.notas_miami.to_s),
        categoria_precio: ERB::Util.html_escape(c.categoria_precio&.nombre.to_s)
      }
    }
  end

  def edit
  end

  def update
    if @cliente.update(cliente_params)
      redirect_to @cliente, notice: "Cliente actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_cliente
    @cliente = Cliente.find(params[:id])
  end

  def authorize_buscar
    require_role(:supervisor_miami, :digitador_miami, :supervisor_prefactura, :supervisor_caja, :cajero)
  end

  def cliente_params
    params.require(:cliente).permit(
      :codigo, :nombre, :apellido, :identidad, :email,
      :telefono, :telefono_whatsapp, :direccion, :ciudad,
      :departamento, :categoria_precio_id, :activo,
      :notas_miami, :notas_honduras
    )
  end
end
