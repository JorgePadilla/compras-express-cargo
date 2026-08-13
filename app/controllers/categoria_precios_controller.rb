class CategoriaPreciosController < ApplicationController
  before_action :require_admin
  before_action :set_categoria, only: %i[show edit update destroy]

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

  # Se puede borrar una categoría que no usa nadie. Los dos
  # `dependent: :restrict_with_error` del modelo son la guarda real; acá lo que
  # importa es que, cuando no se puede, el mensaje diga **por qué**.
  #
  # Hasta ahora la ruta era `except: :destroy`: no había forma de sacar una
  # categoría del sistema, y las de la época vieja se quedaban en la lista para
  # siempre.
  def destroy
    if @categoria.destroy
      redirect_to categoria_precios_path, notice: "Categoria \"#{@categoria.nombre}\" eliminada."
    else
      redirect_to categoria_precios_path,
                  alert: "No se puede eliminar \"#{@categoria.nombre}\". #{@categoria.motivo_no_borrable}"
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
