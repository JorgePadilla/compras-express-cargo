class CategoriaPreciosController < ApplicationController
  before_action :require_admin
  before_action :set_categoria, only: %i[show edit update]

  def index
    # Se precarga `tarifas` porque la pantalla ahora muestra lo que cada
    # categoría cobra de verdad, y sin esto es un N+1 por fila.
    @categorias = CategoriaPrecio.includes(tarifas: [ :tipo_envio, :sucursal ])
                                 .order(:nombre)
  end

  def show
  end

  def new
    @categoria = CategoriaPrecio.new
  end

  def create
    @categoria = CategoriaPrecio.new(categoria_params)
    if @categoria.save
      redirect_to categoria_precios_path, notice: "Categoria de precio creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @categoria.update(categoria_params)
      redirect_to categoria_precios_path, notice: "Categoria de precio actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def require_admin
    redirect_to(root_path, alert: "Solo admin.") unless admin?
  end

  def set_categoria
    @categoria = CategoriaPrecio.find(params[:id])
  end

  # Solo el nombre. Una categoría agrupa clientes; el precio vive en `tarifas`
  # y se edita en /servicios, que es la única pantalla que cobra.
  def categoria_params
    params.require(:categoria_precio).permit(:nombre)
  end
end
