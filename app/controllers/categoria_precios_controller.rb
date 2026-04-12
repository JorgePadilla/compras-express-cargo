class CategoriaPreciosController < ApplicationController
  before_action :require_admin
  before_action :set_categoria, only: %i[show edit update]

  def index
    @categorias = CategoriaPrecio.order(:nombre)
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

  def categoria_params
    params.require(:categoria_precio).permit(:nombre, :precio_libra_aereo, :precio_libra_maritimo, :precio_volumen)
  end
end
